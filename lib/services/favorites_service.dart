import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const String _specialtiesKey = 'favorite_specialties';
  static const String _hospitalsKey = 'favorite_hospitals';

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
}