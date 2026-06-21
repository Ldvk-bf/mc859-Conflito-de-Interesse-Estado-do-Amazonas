import 'package:flutter_test/flutter_test.dart';
import 'package:conflito_de_interesse/models/conflito_record.dart';
import 'package:conflito_de_interesse/services/analytics_service.dart';

ConflittoRecord _record({
  int index = 0,
  String tipoCiclo = 'triangulo',
  String funcionario = 'FULANO',
  String orgao = 'ORG',
  String empresa = 'EMPRESA',
  String cnpj = '',
  String vinculo = 'Estatutário',
  DateTime? periodoInicio,
  DateTime? periodoFim,
  DateTime? dataContrato,
  double valorContrato = 100000.0,
}) {
  return ConflittoRecord(
    index: index,
    tipoCiclo: tipoCiclo,
    funcionario: funcionario,
    socio: 'SOCIO',
    scoreMatch: 1.0,
    metodoMatch: 'exact',
    orgao: orgao,
    empresa: empresa,
    cnpj: cnpj,
    cargo: 'CARGO',
    vinculo: vinculo,
    lotacao: 'LOT',
    remuneracaoTotal: 5000.0,
    periodoInicio: periodoInicio ?? DateTime(2018, 1, 1),
    periodoFim: periodoFim,
    dataContrato: dataContrato ?? DateTime(2019, 6, 1),
    valorContrato: valorContrato,
    descricao: 'DESC',
    qualificacaoSocio: 'SOCIO',
    favoriteKey: 'key$index',
  );
}

void main() {
  group('AnalyticsService', () {
    test('empty input returns AnalyticsData.empty()', () {
      final result = AnalyticsService.compute((filtered: [], all: []));
      expect(result.totalCiclos, 0);
      expect(result.totalContratosUnicos, 0);
      expect(result.totalVinculosUnicos, 0);
    });

    test('same contract (cnpj+date) in 3 rows counted once', () {
      final date = DateTime(2020, 1, 1);
      final rows = [
        _record(index: 0, cnpj: '12345', dataContrato: date, valorContrato: 50000),
        _record(index: 1, cnpj: '12345', dataContrato: date, valorContrato: 50000),
        _record(index: 2, cnpj: '12345', dataContrato: date, valorContrato: 50000),
      ];
      final result = AnalyticsService.compute((filtered: rows, all: rows));
      expect(result.totalContratosUnicos, 1);
      expect(result.totalValorMobilizado, 50000.0);
    });

    test('vínculo normalization maps all known patterns correctly', () {
      final uniqueRecords = [
        _record(index: 0, funcionario: 'A', periodoInicio: DateTime(2015), vinculo: 'Servidor Estatutário Federal'),
        _record(index: 1, funcionario: 'B', periodoInicio: DateTime(2016), vinculo: 'Contrato Temporário'),
        _record(index: 2, funcionario: 'C', periodoInicio: DateTime(2017), vinculo: 'Empregado Celetista'),
        _record(index: 3, funcionario: 'D', periodoInicio: DateTime(2018), vinculo: 'Cargo Comissionado'),
        _record(index: 4, funcionario: 'E', periodoInicio: DateTime(2019), vinculo: 'Bolsista'),
      ];
      final result = AnalyticsService.compute((filtered: uniqueRecords, all: uniqueRecords));
      expect(result.tipoVinculoNasCasos['Estatutário'], 1);
      expect(result.tipoVinculoNasCasos['Temporário'], 1);
      expect(result.tipoVinculoNasCasos['Celetista'], 1);
      expect(result.tipoVinculoNasCasos['Comissionado'], 1);
      expect(result.tipoVinculoNasCasos['Outros'], 1);
    });

    test('histogram: value 0 excluded; 49999 → R\$0–50mil; 5_000_000 → R\$5mi+', () {
      final rows = [
        _record(index: 0, cnpj: 'A', dataContrato: DateTime(2020, 1), valorContrato: 0),
        _record(index: 1, cnpj: 'B', dataContrato: DateTime(2020, 2), valorContrato: 49999),
        _record(index: 2, cnpj: 'C', dataContrato: DateTime(2020, 3), valorContrato: 5000000),
      ];
      final result = AnalyticsService.compute((filtered: rows, all: rows));
      expect(result.contratosExcluidosValorAusente, 1);
      final bins = {for (final b in result.histogramaValor) b.$1: b.$2};
      expect(bins['R\$0–50mil'], 1);
      expect(bins['R\$5mi+'], 1);
      expect(result.totalValorMobilizado, 49999 + 5000000.0);
    });

    test('top 10 empresa ranking with >10 companies returns exactly 10 sorted desc', () {
      final rows = List.generate(15, (i) => _record(
        index: i,
        empresa: 'EMPRESA_$i',
        cnpj: 'cnpj$i',
        funcionario: 'FUNC_${i}_A',
        dataContrato: DateTime(2020, 1, i + 1),
        valorContrato: (i + 1) * 1000.0,
      ));
      // Add extra employee for empresa_0 to ensure it ranks
      final extra = _record(
        index: 100,
        empresa: 'EMPRESA_0',
        cnpj: 'cnpj0',
        funcionario: 'FUNC_0_B',
        periodoInicio: DateTime(2016),
        dataContrato: DateTime(2020, 1, 1),
        valorContrato: 1000.0,
      );
      final all = [...rows, extra];
      final result = AnalyticsService.compute((filtered: all, all: all));
      expect(result.topEmpresas.length, 10);
      // Verify sorted descending
      for (int i = 0; i < result.topEmpresas.length - 1; i++) {
        expect(result.topEmpresas[i].$2 >= result.topEmpresas[i + 1].$2, isTrue);
      }
    });

    test('tipoVinculoNaFolha uses allRecords, not filtered', () {
      final filteredOnly = [
        _record(index: 0, funcionario: 'A', periodoInicio: DateTime(2015), vinculo: 'Temporário'),
      ];
      final allRecords = [
        _record(index: 0, funcionario: 'A', periodoInicio: DateTime(2015), vinculo: 'Temporário'),
        _record(index: 1, funcionario: 'B', periodoInicio: DateTime(2016), vinculo: 'Servidor Estatutário'),
        _record(index: 2, funcionario: 'C', periodoInicio: DateTime(2017), vinculo: 'Celetista'),
      ];
      final result = AnalyticsService.compute((filtered: filteredOnly, all: allRecords));
      // Filtered has only Temporário
      expect(result.tipoVinculoNasCasos.containsKey('Temporário'), isTrue);
      expect(result.tipoVinculoNasCasos.containsKey('Estatutário'), isFalse);
      // All has Temporário, Estatutário, Celetista
      expect(result.tipoVinculoNaFolha.containsKey('Estatutário'), isTrue);
      expect(result.tipoVinculoNaFolha.containsKey('Celetista'), isTrue);
    });
  });
}
