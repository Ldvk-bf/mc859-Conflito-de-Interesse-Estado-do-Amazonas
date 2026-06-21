import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/analytics_data.dart';
import '../providers/data_provider.dart';
import '../services/analytics_export_service.dart';
import '../services/analytics_service.dart';
import '../widgets/analytics/analytics_bar_chart.dart';
import '../widgets/anonymize_toggle_button.dart';
import '../widgets/analytics/analytics_histogram.dart';
import '../widgets/analytics/analytics_metric_card.dart';

class AnalyticsScreen extends StatefulWidget {
  final bool isActive;

  const AnalyticsScreen({super.key, required this.isActive});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  int _lastComputedVersion = -1;
  AnalyticsData? _data;
  bool _computing = false;
  final _fabKey = GlobalKey();

  @override
  void didUpdateWidget(covariant AnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive) {
      final provider = context.read<DataProvider>();
      if (provider.filterVersion != _lastComputedVersion) {
        _startCompute(provider);
      }
    }
  }

  void _startCompute(DataProvider provider) {
    final version = provider.filterVersion;
    final filtered = List.of(provider.filteredRecords);
    final all = List.of(provider.allRecords);
    setState(() => _computing = true);
    compute(
      AnalyticsService.compute,
      (filtered: filtered, all: all),
    ).then((result) {
      if (mounted) {
        setState(() {
          _data = result;
          _lastComputedVersion = version;
          _computing = false;
        });
      }
    });
  }

  static final _currencyFmt = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$ ',
    decimalDigits: 2,
  );

  static String _formatCurrency(double v) => _currencyFmt.format(v);

  Future<void> _export() async {
    final data = _data;
    if (data == null) return;
    try {
      final provider = context.read<DataProvider>();
      final text = AnalyticsExportService.buildExportText(
        data,
        funcNameDisplay: (name) => provider.displayName(name, 'FUNC'),
      );
      final dir = await getTemporaryDirectory();
      await Directory(dir.path).create(recursive: true);
      final file = File('${dir.path}/analise_conflitos.txt');
      await file.writeAsString(text);
      final box = _fabKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/plain')],
        subject: 'Análise de Conflitos de Interesse',
        sharePositionOrigin: origin,
      );
    } catch (e, st) {
      debugPrint('[SHARE_ERROR] ${e.runtimeType}: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao exportar análise.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_computing) {
      return Scaffold(
        appBar: AppBar(title: const Text('Análise')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final data = _data;

    if (data == null || data.totalCiclos == 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('Análise')),
        body: const Center(
          child: Text('Nenhuma instância no conjunto filtrado'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Análise'),
        actions: const [AnonymizeToggleButton()],
      ),
      floatingActionButton: FloatingActionButton(
        key: _fabKey,
        onPressed: _export,
        tooltip: 'Exportar análise',
        child: const Icon(Icons.share),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // T015: small-sample warning
          if (data.totalCiclos < 5)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber,
                      color: Theme.of(context).colorScheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Atenção: conjunto amostral reduzido (${data.totalCiclos} instâncias). Métricas podem não ser representativas.',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.onErrorContainer),
                    ),
                  ),
                ],
              ),
            ),

          // ── Universo Geral ──────────────────────────────────────────
          _SectionHeader(title: 'Universo Geral'),
          AnalyticsMetricCard(
            label: 'Total de instâncias',
            value: '${data.totalCiclos}',
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: AnalyticsMetricCard(
                  label: 'Triângulos',
                  value: '${data.totalTriangulos}',
                  subtitle: '${data.pctTriangulos.toStringAsFixed(1)}%',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnalyticsMetricCard(
                  label: 'Quadrados',
                  value: '${data.totalQuadrados}',
                  subtitle: '${data.pctQuadrados.toStringAsFixed(1)}%',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (data.cicloPorOrgao.isNotEmpty) ...[
            Text('Por órgão', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            AnalyticsBarChart(data: data.cicloPorOrgao),
            const SizedBox(height: 12),
          ],
          if (data.cicloPorVinculo.isNotEmpty) ...[
            Text('Por tipo de vínculo',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            AnalyticsBarChart(data: data.cicloPorVinculo),
            const SizedBox(height: 12),
          ],
          if (data.topEmpresas.isNotEmpty) ...[
            Text(
              'Top 10 empresas',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            // T014: total unique empresas count as subtitle context
            Text(
              'de ${context.read<DataProvider>().filteredRecords.map((r) => r.cnpj.isNotEmpty ? r.cnpj : r.empresa).toSet().length} empresas distintas',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            AnalyticsBarChart(
              data: data.topEmpresas
                  .map((e) => ('${e.$1} (${e.$2})', e.$2))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          if (data.topFuncionarios.isNotEmpty) ...[
            Text(
              'Top 10 funcionários',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            // T014: total unique employee count as subtitle context
            Text(
              'de ${data.totalInstancias} ocorrências',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 4),
            Builder(
              builder: (context) {
                final provider = context.watch<DataProvider>();
                final topFuncs = data.topFuncionarios
                    .map((e) => (provider.displayName(e.$1, 'FUNC'), e.$2))
                    .toList();
                return AnalyticsBarChart(data: topFuncs);
              },
            ),
            const SizedBox(height: 12),
          ],

          // ── Contratos ───────────────────────────────────────────────
          _SectionHeader(title: 'Contratos'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              '${data.totalContratosUnicos} contratos únicos analisados'
              ' (${data.contratosExcluidosValorAusente} excluídos por valor ausente)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Row(
            children: [
              Expanded(
                child: AnalyticsMetricCard(
                  label: 'Média',
                  value: _formatCurrency(data.mediaValorContrato),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnalyticsMetricCard(
                  label: 'Mediana',
                  value: _formatCurrency(data.medianaValorContrato),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: AnalyticsMetricCard(
                  label: 'Desvio padrão',
                  value: _formatCurrency(data.desvioPadraoValorContrato),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnalyticsMetricCard(
                  label: 'Máximo',
                  value: _formatCurrency(data.maxValorContrato),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (data.histogramaValor.isNotEmpty) ...[
            Text('Distribuição de valores',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            AnalyticsHistogram(data: data.histogramaValor),
            const SizedBox(height: 8),
          ],
          AnalyticsMetricCard(
            label: 'Total mobilizado',
            value: _formatCurrency(data.totalValorMobilizado),
          ),
          const SizedBox(height: 8),
          _TimingRow(data: data),
          const SizedBox(height: 12),

          // ── Vínculos ────────────────────────────────────────────────
          _SectionHeader(title: 'Vínculos'),
          if (data.histogramaDuracao.isNotEmpty) ...[
            Text('Duração dos vínculos',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            AnalyticsHistogram(data: data.histogramaDuracao),
            // T014: note about active vínculos (no periodoFim)
            const SizedBox(height: 4),
            Text(
              '${data.histogramaDuracao.fold(0, (s, e) => s + e.$2)} vínculos únicos — vínculos sem data de fim considerados como ativos',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
          ],
          if (data.distribuicaoTemporal.isNotEmpty) ...[
            Text('Distribuição temporal (por ano do contrato)',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            AnalyticsBarChart(
              data: data.distribuicaoTemporal
                  .map((e) => (e.$1.toString(), e.$2))
                  .toList(),
            ),
            const SizedBox(height: 12),
          ],
          _VinculoTypeComparison(data: data),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _TimingRow extends StatelessWidget {
  final AnalyticsData data;
  const _TimingRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data.totalContratosUnicos;
    String pct(int n) => total > 0 ? '${(n / total * 100).toStringAsFixed(1)}%' : '0%';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        'Durante vínculo: ${data.contratosDurante} (${pct(data.contratosDurante)})'
        '  |  Após saída: ${data.contratosApos} (${pct(data.contratosApos)})'
        '  |  Antes: ${data.contratosAntes} (${pct(data.contratosAntes)})',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _VinculoTypeComparison extends StatelessWidget {
  final AnalyticsData data;
  const _VinculoTypeComparison({required this.data});

  @override
  Widget build(BuildContext context) {
    final canonicalTypes = [
      'Estatutário',
      'Temporário',
      'Celetista',
      'Comissionado',
      'Outros',
    ];
    final totalCasos = data.tipoVinculoNasCasos.values.fold(0, (a, b) => a + b);
    final totalFolha = data.tipoVinculoNaFolha.values.fold(0, (a, b) => a + b);

    String pct(int n, int total) =>
        total > 0 ? '${(n / total * 100).toStringAsFixed(1)}%' : '0%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tipo de vínculo', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Nos casos',
                      style: Theme.of(context).textTheme.labelSmall),
                  ...canonicalTypes.map((type) {
                    final n = data.tipoVinculoNasCasos[type] ?? 0;
                    return Text('$type: ${pct(n, totalCasos)}',
                        style: Theme.of(context).textTheme.bodySmall);
                  }),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Na folha geral',
                      style: Theme.of(context).textTheme.labelSmall),
                  ...canonicalTypes.map((type) {
                    final n = data.tipoVinculoNaFolha[type] ?? 0;
                    return Text('$type: ${pct(n, totalFolha)}',
                        style: Theme.of(context).textTheme.bodySmall);
                  }),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
