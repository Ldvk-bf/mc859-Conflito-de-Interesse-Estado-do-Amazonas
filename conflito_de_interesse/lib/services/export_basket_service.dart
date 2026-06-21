import 'package:shared_preferences/shared_preferences.dart';

class ExportBasketService {
  static const _key = 'export_basket_v1';
  Set<int> _basket = {};

  Future<void> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    _basket = (prefs.getStringList(_key) ?? [])
        .map((s) => int.tryParse(s) ?? -1)
        .where((i) => i >= 0)
        .toSet();
  }

  bool contains(int index) => _basket.contains(index);

  Future<void> add(int index) async {
    if (_basket.contains(index)) return;
    _basket.add(index);
    await _persist();
  }

  Future<void> remove(int index) async {
    if (!_basket.contains(index)) return;
    _basket.remove(index);
    await _persist();
  }

  Future<void> clear() async {
    _basket.clear();
    await _persist();
  }

  Set<int> get all => Set.unmodifiable(_basket);
  int get count => _basket.length;

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _basket.map((i) => i.toString()).toList());
  }
}
