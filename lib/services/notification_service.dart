import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../models/ticket_slot.dart';
import '../repositories/health_repository.dart';
import '../services/favorites_service.dart';

const String fetchSlotsTask = "com.omsk.health.fetchSlotsTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != fetchSlotsTask && task != Workmanager.iOSBackgroundTask) {
      return true;
    }

    try {
      if (await FlutterForegroundTask.isRunningService) {
        return true;
      }
      await NotificationService.initializeForBackground();
      final repository = HealthRepository();
      final favoritesService = FavoritesService();
      final subscriptions = await favoritesService.getSlotSubscriptions();
      var succeeded = true;

      for (final sub in subscriptions) {
        try {
          final scheduleUrl = sub['scheduleUrl']!;
          final slots = await repository.getSlots(scheduleUrl);
          final notified = await NotificationService.maybeShowNotification(
            scheduleUrl: scheduleUrl,
            doctorName: sub['doctorName'] ?? 'Врач',
            hospitalName: sub['hospitalName'] ?? 'Больница',
            slots: slots,
          );
          if (notified) {
            await favoritesService.removeSlotSubscription(scheduleUrl);
          }
        } catch (e) {
          debugPrint('Ошибка фоновой проверки талонов: $e');
          succeeded = false;
        }
      }
      return succeeded;
    } catch (e) {
      debugPrint('Ошибка фоновой задачи: $e');
      return false;
    }
  });
}

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static String _slotStateKey(String scheduleUrl, String state) =>
      'slot_notification_${Uri.encodeComponent(scheduleUrl)}_$state';

  static int _notificationId(String value) {
    var hash = 0x811c9dc5;
    for (final codeUnit in value.codeUnits) {
      hash = ((hash ^ codeUnit) * 0x01000193) & 0x7fffffff;
    }
    return hash;
  }

  static Future<void> init() async {
    await _initializePlugin();

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> initializeForBackground() => _initializePlugin();

  static Future<void> _initializePlugin() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(settings: initializationSettings);
  }

  static Future<void> initWorkmanager() async {
    await Workmanager().initialize(callbackDispatcher);

    await Workmanager().registerPeriodicTask(
      "slots_checker_task",
      fetchSlotsTask,
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.update,
    );
  }

  static Future<void> resetSlotTracking(String scheduleUrl) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_slotStateKey(scheduleUrl, 'confirmed'));
    await prefs.remove(_slotStateKey(scheduleUrl, 'pending'));
  }

  static Future<bool> maybeShowNotification({
    required String scheduleUrl,
    required String doctorName,
    required String hospitalName,
    required List<TicketSlot> slots,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final confirmedKey = _slotStateKey(scheduleUrl, 'confirmed');
    final pendingKey = _slotStateKey(scheduleUrl, 'pending');

    if (slots.isEmpty) {
      await prefs.remove(confirmedKey);
      await prefs.remove(pendingKey);
      return false;
    }

    final fingerprint = slots
        .map((slot) => '${slot.id}|${slot.date}|${slot.time}|${slot.type.name}')
        .join(';');

    final confirmedFingerprint = prefs.getString(confirmedKey);
    if (confirmedFingerprint == fingerprint) {
      await prefs.remove(pendingKey);
      return false;
    }

    final pendingFingerprint = prefs.getString(pendingKey);
    if (pendingFingerprint != fingerprint) {
      await prefs.setString(pendingKey, fingerprint);
      return false;
    }

    await showNotification(
      id: _notificationId(scheduleUrl),
      title: 'Появились свободные талоны! 🎉',
      body: '$doctorName ($hospitalName) — доступно талонов: ${slots.length}',
    );
    await prefs.setString(confirmedKey, fingerprint);
    await prefs.remove(pendingKey);
    return true;
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'slots_channel',
      'Отслеживание талонов',
      channelDescription: 'Уведомления о появлении свободных талонов к врачу',
      importance: Importance.max,
      priority: Priority.high,
    );

    const NotificationDetails notificationDetails =
        NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
    );
  }
}