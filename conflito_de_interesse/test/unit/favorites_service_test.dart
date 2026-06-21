import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:conflito_de_interesse/services/favorites_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('contains returns false for unknown key', () async {
    final svc = FavoritesService();
    await svc.loadAll();
    expect(svc.contains('unknown'), isFalse);
  });

  test('toggle adds key when not present', () async {
    final svc = FavoritesService();
    await svc.loadAll();
    await svc.toggle('key1');
    expect(svc.contains('key1'), isTrue);
  });

  test('toggle removes key when already present', () async {
    final svc = FavoritesService();
    await svc.loadAll();
    await svc.toggle('key1');
    await svc.toggle('key1');
    expect(svc.contains('key1'), isFalse);
  });

  test('persistence round-trip survives reload', () async {
    final svc1 = FavoritesService();
    await svc1.loadAll();
    await svc1.toggle('key1');
    await svc1.toggle('key2');

    final svc2 = FavoritesService();
    await svc2.loadAll();
    expect(svc2.contains('key1'), isTrue);
    expect(svc2.contains('key2'), isTrue);
    expect(svc2.contains('key3'), isFalse);
  });

  test('all returns unmodifiable set', () async {
    final svc = FavoritesService();
    await svc.loadAll();
    await svc.toggle('key1');
    expect(() => svc.all.add('key2'), throwsUnsupportedError);
  });
}
