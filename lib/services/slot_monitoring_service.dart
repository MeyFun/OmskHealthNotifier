import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../repositories/health_repository.dart';
import 'favorites_service.dart';
import 'notification_service.dart';

const Duration _slotCheckInterval = Duration(minutes: 5);
const String _checkSubscriptionsCommand = 'check_subscriptions';

@pragma('vm:entry-point')
void startSlotMonitoringCallback() {
  FlutterForegroundTask.setTaskHandler(SlotMonitoringTaskHandler());
}

class SlotMonitoringTaskHandler extends TaskHandler {
  bool _isChecking = false;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    await _checkSubscriptions(timestamp);
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    unawaited(_checkSubscriptions(timestamp));
  }

  @override
  void onReceiveData(Object data) {
    if (data == _checkSubscriptionsCommand) {
      unawaited(_checkSubscriptions(DateTime.now()));
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {}

  Future<void> _checkSubscriptions(DateTime timestamp) async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      await NotificationService.initializeForBackground();
      final repository = HealthRepository();
      final favoritesService = FavoritesService();
      final subscriptions = await favoritesService.getSlotSubscriptions();

      if (subscriptions.isEmpty) {
        await FlutterForegroundTask.stopService();
        return;
      }

      var failedChecks = 0;
      for (final subscription in subscriptions) {
        try {
          final scheduleUrl = subscription['scheduleUrl']!;
          final slots = await repository.getSlots(scheduleUrl);
          final notified = await NotificationService.maybeShowNotification(
            scheduleUrl: scheduleUrl,
            doctorName: subscription['doctorName'] ?? 'Врач',
            hospitalName: subscription['hospitalName'] ?? 'Больница',
            slots: slots,
          );

          if (notified) {
            await favoritesService.removeSlotSubscription(scheduleUrl);
          }
        } catch (error) {
          failedChecks++;
          debugPrint('Ошибка фоновой проверки талонов: $error');
        }
      }

      final remainingSubscriptions = await favoritesService
          .getSlotSubscriptions();
      if (remainingSubscriptions.isEmpty) {
        await FlutterForegroundTask.stopService();
        return;
      }

      final checkedTime =
          '${timestamp.hour.toString().padLeft(2, '0')}:'
          '${timestamp.minute.toString().padLeft(2, '0')}';
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Отслеживание талонов активно',
        notificationText: failedChecks == 0
            ? 'В очереди: ${remainingSubscriptions.length}. Проверено в $checkedTime'
            : 'Не проверено: $failedChecks. Повтор через 5 минут.',
      );
    } catch (error) {
      debugPrint('Ошибка службы отслеживания талонов: $error');
      await FlutterForegroundTask.updateService(
        notificationTitle: 'Отслеживание талонов активно',
        notificationText:
            'Не удалось выполнить проверку. Повтор через 5 минут.',
      );
    } finally {
      _isChecking = false;
    }
  }
}

class SlotMonitoringService {
  static bool _initialized = false;

  static void initialize() {
    if (!Platform.isAndroid || _initialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'slot_monitoring_service',
        channelName: 'Фоновое отслеживание талонов',
        channelDescription:
            'Постоянное уведомление о проверке очередей к врачам',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(
          _slotCheckInterval.inMilliseconds,
        ),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: false,
        stopWithTask: false,
      ),
    );
    _initialized = true;
  }

  static Future<void> syncWithSubscriptions() async {
    if (!Platform.isAndroid) return;
    initialize();

    final subscriptions = await FavoritesService().getSlotSubscriptions();
    if (subscriptions.isEmpty) {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
      return;
    }

    final permission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      final requested =
          await FlutterForegroundTask.requestNotificationPermission();
      if (requested != NotificationPermission.granted) {
        throw StateError('Разрешите уведомления для фонового отслеживания.');
      }
    }

    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask(_checkSubscriptionsCommand);
      return;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: 7312,
      serviceTypes: [ForegroundServiceTypes.dataSync],
      notificationTitle: 'Отслеживание талонов запускается',
      notificationText: 'Подготовка фоновой проверки',
      callback: startSlotMonitoringCallback,
    );

    if (result case ServiceRequestFailure(:final error)) {
      throw Exception('Не удалось запустить фоновую службу: $error');
    }
  }

  static Future<bool> requestBatteryOptimizationExemption() async {
    if (!Platform.isAndroid) return false;
    initialize();

    if (await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
      return true;
    }
    return FlutterForegroundTask.requestIgnoreBatteryOptimization();
  }

  static Future<bool> isIgnoringBatteryOptimizations() async {
    if (!Platform.isAndroid) return false;
    initialize();
    return FlutterForegroundTask.isIgnoringBatteryOptimizations;
  }

  static Future<bool> isRunning() async {
    if (!Platform.isAndroid) return false;
    initialize();
    return FlutterForegroundTask.isRunningService;
  }
}
