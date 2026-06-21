import 'package:intl/intl.dart';
import '../models/analytics_data.dart';

class AnalyticsExportService {
  static final _currencyFmt = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );

  static String buildExportText(AnalyticsData data, {String Function(String)? funcNameDisplay}) {
    final buf = StringBuffer();
    final now = DateTime.now();
    final dateFmt = DateFormat('dd/MM/yyyy HH:mm');

    buf.writeln('ANÁLISE DE CONFLITOS DE INTERESSE — ${dateFmt.format(now)}');
    buf.writeln('Conjunto filtrado: ${data.totalCiclos} instâncias');
    buf.writeln('=' * 55);
    buf.writeln();

    // Universo Geral
    buf.writeln('UNIVERSO GERAL');
    buf.writeln('Total de instâncias: ${data.totalCiclos}');
    buf.writeln(
      'Triângulos: ${data.totalTriangulos} '
      '(${data.pctTriangulos.toStringAsFixed(1)}%)',
    );
    buf.writeln(
      'Quadrados: ${data.totalQuadrados} '
      '(${data.pctQuadrados.toStringAsFixed(1)}%)',
    );
    buf.writeln();

    if (data.cicloPorOrgao.isNotEmpty) {
      buf.writeln('Por órgão:');
      for (final e in data.cicloPorOrgao) {
        buf.writeln('  ${e.$1}: ${e.$2}');
      }
      buf.writeln();
    }

    if (data.cicloPorVinculo.isNotEmpty) {
      buf.writeln('Por tipo de vínculo:');
      for (final e in data.cicloPorVinculo) {
        buf.writeln('  ${e.$1}: ${e.$2}');
      }
      buf.writeln();
    }

    // Contratos
    buf.writeln('CONTRATOS');
    buf.writeln(
      '${data.totalContratosUnicos} contratos únicos analisados'
      ' (${data.contratosExcluidosValorAusente} excluídos por valor ausente)',
    );
    buf.writeln('Média: ${_currencyFmt.format(data.mediaValorContrato)}');
    buf.writeln('Mediana: ${_currencyFmt.format(data.medianaValorContrato)}');
    buf.writeln(
      'Desvio padrão: ${_currencyFmt.format(data.desvioPadraoValorContrato)}',
    );
    buf.writeln('Máximo: ${_currencyFmt.format(data.maxValorContrato)}');
    buf.writeln(
      'Total mobilizado: ${_currencyFmt.format(data.totalValorMobilizado)}',
    );
    buf.writeln();

    // Timing
    final total = data.totalContratosUnicos;
    String pct(int n) =>
        total > 0 ? '${(n / total * 100).toStringAsFixed(1)}%' : '0%';
    buf.writeln('TIMING DOS CONTRATOS');
    buf.writeln(
      'Durante vínculo: ${data.contratosDurante} (${pct(data.contratosDurante)})',
    );
    buf.writeln(
      'Após saída: ${data.contratosApos} (${pct(data.contratosApos)})',
    );
    buf.writeln('Antes: ${data.contratosAntes} (${pct(data.contratosAntes)})');
    buf.writeln();

    // Value histogram
    if (data.histogramaValor.isNotEmpty) {
      buf.writeln('DISTRIBUIÇÃO DE VALORES');
      for (final e in data.histogramaValor) {
        buf.writeln('  ${e.$1}: ${e.$2}');
      }
      buf.writeln();
    }

    // Rankings
    if (data.topEmpresas.isNotEmpty) {
      buf.writeln('TOP 10 EMPRESAS');
      for (var i = 0; i < data.topEmpresas.length; i++) {
        final e = data.topEmpresas[i];
        buf.writeln('  ${i + 1}. ${e.$1}: ${e.$2}');
      }
      buf.writeln();
    }

    if (data.topFuncionarios.isNotEmpty) {
      buf.writeln('TOP 10 FUNCIONÁRIOS');
      for (var i = 0; i < data.topFuncionarios.length; i++) {
        final e = data.topFuncionarios[i];
        final name = funcNameDisplay?.call(e.$1) ?? e.$1;
        buf.writeln('  ${i + 1}. $name: ${e.$2}');
      }
      buf.writeln();
    }

    // Temporal distribution
    if (data.distribuicaoTemporal.isNotEmpty) {
      buf.writeln('DISTRIBUIÇÃO TEMPORAL (por ano do contrato)');
      for (final e in data.distribuicaoTemporal) {
        buf.writeln('  ${e.$1}: ${e.$2}');
      }
      buf.writeln();
    }

    // Duration histogram
    if (data.histogramaDuracao.isNotEmpty) {
      buf.writeln('DURAÇÃO DOS VÍNCULOS');
      for (final e in data.histogramaDuracao) {
        buf.writeln('  ${e.$1}: ${e.$2}');
      }
      buf.writeln();
    }

    // Vínculo type comparison
    if (data.tipoVinculoNasCasos.isNotEmpty) {
      final totalCasos =
          data.tipoVinculoNasCasos.values.fold(0, (a, b) => a + b);
      final totalFolha =
          data.tipoVinculoNaFolha.values.fold(0, (a, b) => a + b);
      String pctMap(int n, int t) =>
          t > 0 ? '${(n / t * 100).toStringAsFixed(1)}%' : '0%';

      buf.writeln('TIPO DE VÍNCULO — NOS CASOS');
      for (final e in data.tipoVinculoNasCasos.entries) {
        buf.writeln('  ${e.key}: ${pctMap(e.value, totalCasos)}');
      }
      buf.writeln();

      buf.writeln('TIPO DE VÍNCULO — NA FOLHA GERAL');
      for (final e in data.tipoVinculoNaFolha.entries) {
        buf.writeln('  ${e.key}: ${pctMap(e.value, totalFolha)}');
      }
    }

    return buf.toString();
  }
}
