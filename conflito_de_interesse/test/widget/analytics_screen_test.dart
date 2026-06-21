import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:conflito_de_interesse/models/conflito_record.dart';
import 'package:conflito_de_interesse/providers/data_provider.dart';
import 'package:conflito_de_interesse/screens/analytics_screen.dart';

class _MockDataProvider extends DataProvider {
  final List<ConflittoRecord> _records;
  final int _version;

  _MockDataProvider({required List<ConflittoRecord> records, int version = 1})
      : _records = records,
        _version = version;

  @override
  List<ConflittoRecord> get filteredRecords => _records;
  @override
  List<ConflittoRecord> get allRecords => _records;
  @override
  bool get loading => false;
  @override
  int get filterVersion => _version;
}

ConflittoRecord _record(int index) => ConflittoRecord(
      index: index,
      tipoCiclo: 'triangulo',
      funcionario: 'FUNCIONARIO_$index',
      socio: 'SOCIO',
      scoreMatch: 1.0,
      metodoMatch: 'exact',
      orgao: 'ORG_$index',
      empresa: 'EMPRESA_$index',
      cnpj: 'cnpj$index',
      cargo: 'CARGO',
      vinculo: 'Estatutário',
      lotacao: 'LOT',
      remuneracaoTotal: 5000.0,
      periodoInicio: DateTime(2018, 1, 1),
      periodoFim: DateTime(2022, 1, 1),
      dataContrato: DateTime(2019, index + 1, 1),
      valorContrato: (index + 1) * 50000.0,
      descricao: 'DESC',
      qualificacaoSocio: 'SOCIO',
      favoriteKey: 'key$index',
    );

Widget _wrap(Widget child, DataProvider provider) {
  return ChangeNotifierProvider<DataProvider>.value(
    value: provider,
    child: MaterialApp(home: child),
  );
}

void main() {
  group('AnalyticsScreen', () {
    testWidgets('renders loading indicator when isActive switches true with stale version',
        (tester) async {
      final provider = _MockDataProvider(records: [_record(0)], version: 1);
      final key = GlobalKey<State>();

      await tester.pumpWidget(
        _wrap(AnalyticsScreen(key: key, isActive: false), provider),
      );

      await tester.pumpWidget(
        _wrap(AnalyticsScreen(key: key, isActive: true), provider),
      );

      // Single pump — compute hasn't resolved yet, loading indicator visible
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders empty state when filteredRecords is empty', (tester) async {
      final provider = _MockDataProvider(records: [], version: 1);
      final key = GlobalKey<State>();

      await tester.pumpWidget(
        _wrap(AnalyticsScreen(key: key, isActive: false), provider),
      );

      await tester.pumpWidget(
        _wrap(AnalyticsScreen(key: key, isActive: true), provider),
      );
      await tester.pump(); // start compute, _computing = true

      // compute() runs in a real isolate — use runAsync to let it finish
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 500)));

      await tester.pump(); // process setState(_computing = false, _data = empty)
      expect(find.text('Nenhuma instância no conjunto filtrado'), findsOneWidget);
    });

    testWidgets('renders Universo Geral section after compute completes', (tester) async {
      final records = List.generate(5, _record);
      final provider = _MockDataProvider(records: records, version: 1);
      final key = GlobalKey<State>();

      await tester.pumpWidget(
        _wrap(AnalyticsScreen(key: key, isActive: false), provider),
      );

      await tester.pumpWidget(
        _wrap(AnalyticsScreen(key: key, isActive: true), provider),
      );
      await tester.pump(); // start compute, _computing = true

      // compute() runs in a real isolate — use runAsync to let it finish
      await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));

      await tester.pumpAndSettle();
      expect(find.text('Universo Geral'), findsOneWidget);
      expect(find.text('Total de instâncias'), findsOneWidget);
    });

    testWidgets('FAB present with share icon after compute completes with data', (tester) async {
      final records = List.generate(5, _record);
      final provider = _MockDataProvider(records: records, version: 1);
      final key = GlobalKey<State>();

      await tester.pumpWidget(
        _wrap(AnalyticsScreen(key: key, isActive: false), provider),
      );

      await tester.pumpWidget(
        _wrap(AnalyticsScreen(key: key, isActive: true), provider),
      );
      await tester.pump(); // start compute

      await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));

      await tester.pumpAndSettle();
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byIcon(Icons.share), findsOneWidget);
    });

    testWidgets('FAB absent when screen not yet activated', (tester) async {
      final provider = _MockDataProvider(records: [_record(0)], version: 1);
      await tester.pumpWidget(
        _wrap(AnalyticsScreen(isActive: false), provider),
      );
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('FAB absent while computing (_computing == true)', (tester) async {
      final records = List.generate(5, _record);
      final provider = _MockDataProvider(records: records, version: 1);
      final key = GlobalKey<State>();

      await tester.pumpWidget(
        _wrap(AnalyticsScreen(key: key, isActive: false), provider),
      );

      // Activate — triggers compute, which is in-flight
      await tester.pumpWidget(
        _wrap(AnalyticsScreen(key: key, isActive: true), provider),
      );

      // Single pump: compute still running, loading spinner visible, no FAB
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });
}
