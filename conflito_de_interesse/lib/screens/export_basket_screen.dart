import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/conflito_record.dart';
import '../models/filter_state.dart';
import '../providers/data_provider.dart';
import '../services/export_service.dart';
import '../widgets/anonymize_toggle_button.dart';
import '../services/filter_service.dart';
import '../widgets/sortable_column_header.dart';
import 'detail_screen.dart';

final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

class ExportBasketScreen extends StatefulWidget {
  const ExportBasketScreen({super.key});

  @override
  State<ExportBasketScreen> createState() => _ExportBasketScreenState();
}

class _ExportBasketScreenState extends State<ExportBasketScreen> {
  bool _exporting = false;
  final _fabKey = GlobalKey();
  SortColumn _sortColumn = SortColumn.none;
  SortDirection _sortDirection = SortDirection.asc;

  List<ConflittoRecord> _applySort(List<ConflittoRecord> records) {
    if (_sortColumn == SortColumn.none) return records;
    return FilterService().sortFavorites(
      records,
      FilterState.defaults().copyWith(
        favoriteSortColumn: _sortColumn,
        favoriteSortDirection: _sortDirection,
      ),
    );
  }

  void _updateSort(SortColumn col) {
    setState(() {
      if (_sortColumn == col) {
        _sortDirection = _sortDirection == SortDirection.asc
            ? SortDirection.desc
            : SortDirection.asc;
      } else {
        _sortColumn = col;
        _sortDirection = SortDirection.asc;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DataProvider>(
      builder: (context, data, _) {
        final records = data.basketRecords;
        final sorted = _applySort(records);
        return Scaffold(
          appBar: AppBar(
            title: Text('Exportar (${data.basketCount})'),
            actions: [
              const AnonymizeToggleButton(),
              if (records.isNotEmpty)
                TextButton(
                  onPressed: () => _confirmClear(context, data),
                  child: const Text('Limpar cesta'),
                ),
            ],
          ),
          body: records.isEmpty
              ? const Center(
                  child: Text('Nenhum registro na cesta'),
                )
              : Column(
                  children: [
                    if (records.length > 1000)
                      MaterialBanner(
                        content: Text(
                          'Aviso: ${records.length} registros podem gerar um arquivo grande.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => ScaffoldMessenger.of(context)
                                .hideCurrentMaterialBanner(),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    SortableColumnHeader(
                      activeColumn: _sortColumn,
                      activeDirection: _sortDirection,
                      onTap: _updateSort,
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: sorted.length,
                        itemBuilder: (context, i) {
                          final r = sorted[i];
                          return ListTile(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DetailScreen(record: r),
                              ),
                            ),
                            title: Text(
                              r.funcionario,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${r.orgao} | ${r.empresa}\n${_brl.format(r.valorContrato)}',
                            ),
                            isThreeLine: true,
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => data.removeFromBasket(r.index),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          floatingActionButton: records.isNotEmpty
              ? FloatingActionButton.extended(
                  key: _fabKey,
                  onPressed: _exporting ? null : () => _export(context, data),
                  icon: _exporting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download),
                  label: const Text('Exportar CSV'),
                )
              : null,
        );
      },
    );
  }

  void _confirmClear(BuildContext context, DataProvider data) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Limpar cesta'),
        content: const Text(
            'Remover todos os registros da cesta de exportação?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              data.clearBasket();
              Navigator.pop(context);
            },
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context, DataProvider data) async {
    setState(() => _exporting = true);
    try {
      final box = _fabKey.currentContext?.findRenderObject() as RenderBox?;
      final origin = box != null ? box.localToGlobal(Offset.zero) & box.size : null;
      await ExportService().exportBasket(
        _applySort(data.basketRecords),
        sharePositionOrigin: origin,
        nameDisplay: data.displayName,
      );
    } catch (e, st) {
      debugPrint('[SHARE_ERROR] ${e.runtimeType}: $e\n$st');
      if (!context.mounted) return;
      final msg = e is PlatformException
          ? 'Não foi possível abrir o compartilhamento. Tente novamente.'
          : 'Erro ao gerar o arquivo CSV. Tente novamente.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
