import 'package:flutter_test/flutter_test.dart';
import 'package:conflito_de_interesse/models/conflito_record.dart';

List<dynamic> _row({
  String tipoCiclo = 'triangulo',
  String funcionario = 'Joao Silva',
  String socio = 'Joao Silva',
  String score = '100,00',
  String metodo = 'exact',
  String orgao = 'SEAD',
  String empresa = 'Empresa Teste',
  String cnpj = '12345678000190',
  String cargo = 'ANALISTA',
  String funcao = '',
  String vinculo = 'ESTATUTARIO',
  String lotacao = 'Lotacao',
  String remuneracao = '5.000,00',
  String periodoInicio = '2018-01',
  String periodoFim = '',
  String dataContrato = '15/06/2020',
  String valorContrato = '50.000,00',
  String descricao = 'Contrato',
  String qualificacao = 'Socio-Administrador',
}) =>
    [
      tipoCiclo, funcionario, socio, score, metodo, orgao, empresa, cnpj,
      cargo, funcao, vinculo, lotacao, remuneracao, periodoInicio, periodoFim,
      dataContrato, valorContrato, descricao, qualificacao,
    ];

void main() {
  group('ConflittoRecord.fromRow', () {
    test('parses basic row correctly', () {
      final rec = ConflittoRecord.fromRow(0, _row());
      expect(rec.funcionario, 'Joao Silva');
      expect(rec.tipoCiclo, 'triangulo');
      expect(rec.scoreMatch, 100.0);
      expect(rec.remuneracaoTotal, 5000.0);
      expect(rec.valorContrato, 50000.0);
      expect(rec.dataContrato, DateTime(2020, 6, 15));
      expect(rec.periodoInicio, DateTime(2018, 1, 1));
      expect(rec.periodoFim, isNull);
    });

    test('parses periodoFim when present', () {
      final rec = ConflittoRecord.fromRow(0, _row(periodoFim: '2022-03'));
      expect(rec.periodoFim, DateTime(2022, 3, 1));
    });

    test('null funcao for empty string', () {
      final rec = ConflittoRecord.fromRow(0, _row(funcao: ''));
      expect(rec.funcao, isNull);
    });

    test('null funcao for literal "null" string', () {
      final rec = ConflittoRecord.fromRow(0, _row(funcao: 'null'));
      expect(rec.funcao, isNull);
    });

    test('tipoCiclo is lowercased', () {
      final rec = ConflittoRecord.fromRow(0, _row(tipoCiclo: 'TRIANGULO'));
      expect(rec.tipoCiclo, 'triangulo');
    });

    test('favoriteKey is stable and non-empty', () {
      final rec1 = ConflittoRecord.fromRow(0, _row());
      final rec2 = ConflittoRecord.fromRow(99, _row());
      expect(rec1.favoriteKey, isNotEmpty);
      expect(rec1.favoriteKey, equals(rec2.favoriteKey));
    });

    test('favoriteKey differs for different cnpj', () {
      final rec1 = ConflittoRecord.fromRow(0, _row(cnpj: '11111111000111'));
      final rec2 = ConflittoRecord.fromRow(0, _row(cnpj: '22222222000222'));
      expect(rec1.favoriteKey, isNot(equals(rec2.favoriteKey)));
    });

    test('parses BR decimal format with period thousands separator', () {
      final rec =
          ConflittoRecord.fromRow(0, _row(valorContrato: '1.234.567,89'));
      expect(rec.valorContrato, closeTo(1234567.89, 0.01));
    });
  });
}
