import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:conflito_de_interesse/models/conflito_record.dart';
import 'package:conflito_de_interesse/providers/data_provider.dart';
import 'package:conflito_de_interesse/widgets/result_list_item.dart';

ConflittoRecord _rec(String funcionario) => ConflittoRecord(
      index: 0,
      tipoCiclo: 'triangulo',
      funcionario: funcionario,
      socio: 'Sócio Teste',
      scoreMatch: 100,
      metodoMatch: 'exact',
      orgao: 'SEAD',
      empresa: 'Empresa Teste',
      cnpj: '12345678000190',
      cargo: 'ANALISTA',
      vinculo: 'ESTATUTARIO',
      lotacao: 'LOC',
      remuneracaoTotal: 5000,
      periodoInicio: DateTime(2020, 1, 1),
      periodoFim: DateTime(2023, 1, 1),
      dataContrato: DateTime(2021, 6, 1),
      valorContrato: 50000,
      descricao: 'Desc',
      qualificacaoSocio: 'Sócio',
      favoriteKey: 'key_0',
    );

Widget _wrap(DataProvider provider, ConflittoRecord record) =>
    ChangeNotifierProvider<DataProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(body: ResultListItem(record: record)),
      ),
    );

void main() {
  group('ResultListItem — anonymization', () {
    testWidgets('shows anonymized code (not raw name) when anonymized=true', (tester) async {
      final provider = DataProvider();
      expect(provider.anonymized, isTrue);
      final record = _rec('Nome Real Teste');

      await tester.pumpWidget(_wrap(provider, record));

      // Raw name must not appear; code or placeholder must appear
      expect(find.text('Nome Real Teste'), findsNothing);
      // The display name follows FUNC-XXXXXX pattern (or placeholder FUNC-??????)
      final displayText = provider.displayName('Nome Real Teste', 'FUNC');
      expect(find.text(displayText), findsOneWidget);
      expect(displayText.startsWith('FUNC-'), isTrue);
    });

    testWidgets('shows only name (no code) when anonymized=false', (tester) async {
      final provider = DataProvider()..toggleAnonymization();
      expect(provider.anonymized, isFalse);
      final record = _rec('Nome Real Teste');

      await tester.pumpWidget(_wrap(provider, record));

      final displayText = provider.displayName('Nome Real Teste', 'FUNC');
      expect(displayText, equals('Nome Real Teste'));
      expect(displayText.contains(' — '), isFalse);
      expect(find.text('Nome Real Teste'), findsOneWidget);
    });

    testWidgets('two items with same name show same code when anonymized=true', (tester) async {
      final provider = DataProvider();
      final record1 = _rec('Pessoa Comum');
      final record2 = ConflittoRecord(
        index: 1,
        tipoCiclo: 'triangulo',
        funcionario: 'Pessoa Comum',
        socio: 'Sócio B',
        scoreMatch: 100,
        metodoMatch: 'exact',
        orgao: 'SEAD',
        empresa: 'Outra Empresa',
        cnpj: '99999999000199',
        cargo: 'ANALISTA',
        vinculo: 'ESTATUTARIO',
        lotacao: 'LOC',
        remuneracaoTotal: 3000,
        periodoInicio: DateTime(2019, 1, 1),
        periodoFim: DateTime(2022, 1, 1),
        dataContrato: DateTime(2020, 3, 1),
        valorContrato: 20000,
        descricao: 'Outra desc',
        qualificacaoSocio: 'Sócio',
        favoriteKey: 'key_1',
      );

      final code1 = provider.displayName(record1.funcionario, 'FUNC');
      final code2 = provider.displayName(record2.funcionario, 'FUNC');
      expect(code1, code2);
    });
  });
}
