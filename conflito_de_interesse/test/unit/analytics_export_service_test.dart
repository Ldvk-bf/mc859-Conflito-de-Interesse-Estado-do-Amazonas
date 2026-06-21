import 'package:flutter_test/flutter_test.dart';
import 'package:conflito_de_interesse/models/analytics_data.dart';
import 'package:conflito_de_interesse/services/analytics_export_service.dart';

AnalyticsData _fullData() => AnalyticsData(
      totalInstancias: 42,
      computedAt: DateTime(2024, 6, 1),
      totalCiclos: 30,
      totalTriangulos: 20,
      totalQuadrados: 10,
      pctTriangulos: 66.7,
      pctQuadrados: 33.3,
      cicloPorOrgao: [('SEFAZ', 15), ('SESP', 15)],
      cicloPorVinculo: [('Estatutário', 30)],
      topEmpresas: [('EMPRESA A (10)', 10)],
      topFuncionarios: [('FULANO (5)', 5)],
      totalContratosUnicos: 25,
      contratosExcluidosValorAusente: 2,
      mediaValorContrato: 150000.0,
      medianaValorContrato: 120000.0,
      desvioPadraoValorContrato: 30000.0,
      maxValorContrato: 500000.0,
      totalValorMobilizado: 3750000.0,
      histogramaValor: [('R\$50mil–200mil', 20), ('R\$200mil–1mi', 5)],
      contratosDurante: 10,
      contratosApos: 12,
      contratosAntes: 3,
      contratosTimingDesconhecido: 0,
      totalVinculosUnicos: 18,
      histogramaDuracao: [('0–6 meses', 5), ('6–12 meses', 13)],
      distribuicaoTemporal: [(2020, 8), (2021, 17)],
      tipoVinculoNasCasos: {'Estatutário': 25, 'Temporário': 5},
      tipoVinculoNaFolha: {'Estatutário': 100, 'Temporário': 20, 'Celetista': 30},
    );

void main() {
  group('AnalyticsExportService.buildExportText', () {
    late String result;

    setUpAll(() {
      result = AnalyticsExportService.buildExportText(_fullData());
    });

    test('contains Universo Geral section header', () {
      expect(result, contains('UNIVERSO GERAL'));
    });

    test('contains total instances and triangle/square counts', () {
      expect(result, contains('30'));
      expect(result, contains('Triângulos: 20'));
      expect(result, contains('Quadrados: 10'));
    });

    test('contains por-orgao entries', () {
      expect(result, contains('SEFAZ'));
      expect(result, contains('SESP'));
    });

    test('contains Contratos section with all 5 metrics', () {
      expect(result, contains('CONTRATOS'));
      expect(result, contains('Média:'));
      expect(result, contains('Mediana:'));
      expect(result, contains('Desvio padrão:'));
      expect(result, contains('Máximo:'));
      expect(result, contains('Total mobilizado:'));
    });

    test('monetary values use pt_BR format (comma decimal)', () {
      // R$ 150.000,00 — comma as decimal separator
      expect(result, contains(',00'));
    });

    test('contains timing section', () {
      expect(result, contains('TIMING DOS CONTRATOS'));
      expect(result, contains('Durante vínculo'));
      expect(result, contains('Após saída'));
      expect(result, contains('Antes:'));
    });

    test('contains value histogram section', () {
      expect(result, contains('DISTRIBUIÇÃO DE VALORES'));
      expect(result, contains('R\$50mil–200mil'));
    });

    test('contains top empresas ranking', () {
      expect(result, contains('TOP 10 EMPRESAS'));
      expect(result, contains('EMPRESA A'));
    });

    test('contains top funcionarios ranking', () {
      expect(result, contains('TOP 10 FUNCIONÁRIOS'));
      expect(result, contains('FULANO'));
    });

    test('contains temporal distribution', () {
      expect(result, contains('DISTRIBUIÇÃO TEMPORAL'));
      expect(result, contains('2020'));
      expect(result, contains('2021'));
    });

    test('contains duration histogram', () {
      expect(result, contains('DURAÇÃO DOS VÍNCULOS'));
      expect(result, contains('0–6 meses'));
    });

    test('contains vínculo type breakdown for cases and folha', () {
      expect(result, contains('TIPO DE VÍNCULO — NOS CASOS'));
      expect(result, contains('TIPO DE VÍNCULO — NA FOLHA GERAL'));
      expect(result, contains('Estatutário'));
    });

    test('empty data produces minimal output without crashing', () {
      final empty = AnalyticsData.empty();
      final text = AnalyticsExportService.buildExportText(empty);
      expect(text, contains('UNIVERSO GERAL'));
      expect(text, contains('CONTRATOS'));
    });
  });
}
