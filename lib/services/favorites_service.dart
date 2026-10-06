import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class FavoritesService {
  static const String _specialtiesKey = 'favorite_specialties';
  static const String _hospitalsKey = 'favorite_hospitals';
  static const String _subscriptionsKey = 'slot_subscriptions';

  // --- ИЗБРАННЫЕ СПЕЦИАЛЬНОСТИ ---
  Future<List<String>> getFavoriteSpecialties() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_specialtiesKey) ?? [];
  }

  Future<void> toggleFavoriteSpecialty(String title) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_specialtiesKey) ?? [];
    if (favorites.contains(title)) {
      favorites.remove(title);
    } else {
      favorites.add(title);
    }
    await prefs.setStringList(_specialtiesKey, favorites);
  }

  // --- ИЗБРАННЫЕ БОЛЬНИЦЫ ---
  Future<List<String>> getFavoriteHospitals() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_hospitalsKey) ?? [];
  }

  Future<void> toggleFavoriteHospital(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = prefs.getStringList(_hospitalsKey) ?? [];
    if (favorites.contains(name)) {
      favorites.remove(name);
    } else {
      favorites.add(name);
    }
    await prefs.setStringList(_hospitalsKey, favorites);
  }

  // --- ПОДПИСКИ НА ТАЛОНЫ ---
  Future<List<Map<String, String>>> getSlotSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> rawList = prefs.getStringList(_subscriptionsKey) ?? [];
    return rawList
        .map((item) => Map<String, String>.from(jsonDecode(item)))
        .toList();
  }

  Future<bool> isSubscribed(String scheduleUrl) async {
    final subscriptions = await getSlotSubscriptions();
    return subscriptions.any((sub) => sub['scheduleUrl'] == scheduleUrl);
  }

  // Явный метод добавления подписки
  Future<void> addSlotSubscription({
    required String scheduleUrl,
    required String doctorName,
    required String hospitalName,
  }) async {
    final isAlreadySubscribed = await isSubscribed(scheduleUrl);
    if (!isAlreadySubscribed) {
      await toggleSubscription(
        hospitalName: hospitalName,
        doctorName: doctorName,
        scheduleUrl: scheduleUrl,
      );
    }
  }

  // Явный метод удаления подписки
  Future<void> removeSlotSubscription(String scheduleUrl) async {
    final prefs = await SharedPreferences.getInstance();
    final subscriptions = await getSlotSubscriptions();
    subscriptions.removeWhere((sub) => sub['scheduleUrl'] == scheduleUrl);
    await prefs.setStringList(
      _subscriptionsKey,
      subscriptions.map((item) => jsonEncode(item)).toList(),
    );
  }

  // Переключение состояния (добавить/удалить)
  Future<void> toggleSubscription({
    required String hospitalName,
    required String doctorName,
    required String scheduleUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<Map<String, String>> subscriptions = await getSlotSubscriptions();

    final index =
        subscriptions.indexWhere((sub) => sub['scheduleUrl'] == scheduleUrl);

    if (index >= 0) {
      subscriptions.removeAt(index);
    } else {
      subscriptions.add({
        'hospitalName': hospitalName,
        'doctorName': doctorName,
        'scheduleUrl': scheduleUrl,
      });
    }

    final encodedList =
        subscriptions.map((item) => jsonEncode(item)).toList();
    await prefs.setStringList(_subscriptionsKey, encodedList);
  }
}