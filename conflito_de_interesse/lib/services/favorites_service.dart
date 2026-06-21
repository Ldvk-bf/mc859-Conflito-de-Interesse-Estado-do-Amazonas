import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
  static const _key = 'favorites_v1';
  Set<String> _favorites = {};

  Future<void> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    _favorites = (prefs.getStringList(_key) ?? []).toSet();
  }

  bool contains(String key) => _favorites.contains(key);

  Future<void> toggle(String key) async {
    if (_favorites.contains(key)) {
      _favorites.remove(key);
    } else {
      _favorites.add(key);
    }
    await _persist();
  }

  Set<String> get all => Set.unmodifiable(_favorites);

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _favorites.toList());
  }
}
