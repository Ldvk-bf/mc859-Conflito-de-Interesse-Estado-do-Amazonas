import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../providers/filter_provider.dart';
import '../widgets/result_list_item.dart';
import '../widgets/filter_panel.dart';
import '../widgets/sortable_column_header.dart';
import '../services/export_service.dart';
import '../widgets/anonymize_toggle_button.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final filter = context.watch<FilterProvider>();
    final records = data.filteredRecords;
    final total = data.allRecords.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Conflito de Interesse',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        actions: [
          const AnonymizeToggleButton(),
          const _ShareButton(),
          if (filter.state.hasActiveFilters)
            TextButton.icon(
              onPressed: filter.reset,
              icon: const Icon(Icons.filter_alt_off, size: 18),
              label: const Text('Limpar'),
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filtros',
            onPressed: () => _showFilterPanel(context),
          ),
        ],
      ),
      body: Column(
        children: [
          _CounterBar(filtered: records.length, total: total),
          SortableColumnHeader(
            activeColumn: filter.state.sortColumn,
            activeDirection: filter.state.sortDirection,
            onTap: filter.updateSort,
          ),
          Expanded(
            child: records.isEmpty
                ? const Center(child: Text('Nenhum resultado encontrado.'))
                : ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (_, i) =>
                        ResultListItem(record: records[i]),
                  ),
          ),
        ],
      ),
    );
  }

  void _showFilterPanel(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<FilterProvider>(),
        child: ChangeNotifierProvider.value(
          value: context.read<DataProvider>(),
          child: const FilterPanel(),
        ),
      ),
    );
  }
}

class _ShareButton extends StatefulWidget {
  const _ShareButton();

  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  final _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    if (data.filteredRecords.isEmpty) return const SizedBox.shrink();
    return IconButton(
      key: _key,
      icon: const Icon(Icons.share),
      tooltip: 'Exportar resultados',
      onPressed: () async {
        final box = _key.currentContext?.findRenderObject() as RenderBox?;
        final origin =
            box != null ? box.localToGlobal(Offset.zero) & box.size : null;
        try {
          await ExportService().export(
            data.filteredRecords,
            'conflito_resultados',
            sharePositionOrigin: origin,
          );
        } catch (e, st) {
          debugPrint('[SHARE_ERROR] ${e.runtimeType}: $e\n$st');
          if (!context.mounted) return;
          final msg = e is PlatformException
              ? 'Não foi possível abrir o compartilhamento. Tente novamente.'
              : 'Erro ao gerar o arquivo CSV. Tente novamente.';
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
      },
    );
  }
}

class _CounterBar extends StatelessWidget {
  final int filtered;
  final int total;

  const _CounterBar({required this.filtered, required this.total});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
        '$filtered de $total registros',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
