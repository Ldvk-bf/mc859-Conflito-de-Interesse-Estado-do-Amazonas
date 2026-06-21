import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:conflito_de_interesse/models/conflito_record.dart';
import 'package:conflito_de_interesse/providers/data_provider.dart';
import 'package:conflito_de_interesse/widgets/result_list_item.dart';
import 'package:conflito_de_interesse/widgets/timing_label_badge.dart';

ConflittoRecord _rec({
  required DateTime periodoInicio,
  DateTime? periodoFim,
  required DateTime dataContrato,
}) {
  return ConflittoRecord(
    index: 0,
    tipoCiclo: 'triangulo',
    funcionario: 'Test User',
    socio: 'Test User',
    scoreMatch: 100,
    metodoMatch: 'exact',
    orgao: 'SEAD',
    empresa: 'Empresa Teste',
    cnpj: '12345678000190',
    cargo: 'ANALISTA',
    vinculo: 'ESTATUTARIO',
    lotacao: 'LOC',
    remuneracaoTotal: 5000,
    periodoInicio: periodoInicio,
    periodoFim: periodoFim,
    dataContrato: dataContrato,
    valorContrato: 50000,
    descricao: 'Desc',
    qualificacaoSocio: 'Sócio',
    favoriteKey: 'key_0',
  );
}

Widget _wrap(ConflittoRecord record) {
  final data = DataProvider();
  return ChangeNotifierProvider.value(
    value: data,
    child: MaterialApp(
      home: Scaffold(body: ResultListItem(record: record)),
    ),
  );
}

void main() {
  group('ResultListItem — TimingLabelBadge', () {
    testWidgets('renders TimingLabelBadge for durante record', (tester) async {
      final record = _rec(
        periodoInicio: DateTime(2018, 1, 1),
        periodoFim: DateTime(2023, 1, 1),
        dataContrato: DateTime(2020, 1, 1),
      );
      await tester.pumpWidget(_wrap(record));
      expect(find.byType(TimingLabelBadge), findsOneWidget);
    });

    testWidgets('renders TimingLabelBadge for antes record', (tester) async {
      final record = _rec(
        periodoInicio: DateTime(2020, 1, 1),
        dataContrato: DateTime(2018, 1, 1),
      );
      await tester.pumpWidget(_wrap(record));
      expect(find.byType(TimingLabelBadge), findsOneWidget);
    });

    testWidgets('renders TimingLabelBadge for apos record', (tester) async {
      final record = _rec(
        periodoInicio: DateTime(2015, 1, 1),
        periodoFim: DateTime(2018, 1, 1),
        dataContrato: DateTime(2019, 1, 1),
      );
      await tester.pumpWidget(_wrap(record));
      expect(find.byType(TimingLabelBadge), findsOneWidget);
    });

    testWidgets('durante badge shows compact "Durante" text', (tester) async {
      final record = _rec(
        periodoInicio: DateTime(2018, 1, 1),
        periodoFim: DateTime(2023, 1, 1),
        dataContrato: DateTime(2020, 1, 1),
      );
      await tester.pumpWidget(_wrap(record));
      expect(find.text('Durante'), findsOneWidget);
    });

    testWidgets('displays orgao and empresa separated by |', (tester) async {
      final record = _rec(
        periodoInicio: DateTime(2018, 1, 1),
        periodoFim: DateTime(2023, 1, 1),
        dataContrato: DateTime(2020, 1, 1),
      );
      await tester.pumpWidget(_wrap(record));
      expect(find.text('SEAD | Empresa Teste'), findsOneWidget);
    });
  });
}
