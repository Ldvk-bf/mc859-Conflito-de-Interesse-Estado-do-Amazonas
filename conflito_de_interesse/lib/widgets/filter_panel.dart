import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import '../providers/filter_provider.dart';
import 'filters/timing_category_filter.dart';
import 'cycle_type_filter.dart';
import 'score_range_filter.dart';
import 'financial_threshold_filter.dart';
import 'searchable_checklist.dart';
import 'name_search_filter.dart';

class FilterPanel extends StatelessWidget {
  const FilterPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final filter = context.watch<FilterProvider>();
    final state = filter.state;

    if (data.invalidatedCargos != null && data.invalidatedCargos!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        data.clearInvalidatedCargos();
        if (state.cargosSelecionados != null) {
          final validSelection = state.cargosSelecionados!.intersection(data.contextualCargos);
          context.read<FilterProvider>().updateCategorical(
            cargos: () => validSelection.isEmpty ? null : validSelection,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cargo não disponível com os filtros atuais'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    }

    if (data.invalidatedEmpresas != null && data.invalidatedEmpresas!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        data.clearInvalidatedEmpresas();
        if (state.empresasSelecionadas != null) {
          final validSelection = state.empresasSelecionadas!.intersection(data.contextualEmpresas);
          context.read<FilterProvider>().updateCategorical(
            empresas: () => validSelection.isEmpty ? null : validSelection,
          );
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Empresa não disponível com os filtros atuais'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      });
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          _handle(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Filtros',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: filter.reset,
                  child: const Text('Limpar tudo'),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollController,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                const NameSearchFilter(),
                const SizedBox(height: 8),
                _FilterTile(
                  title: 'Temporalidade',
                  child: TimingCategoryFilter(
                    selected: state.timingCategoriesSelecionadas,
                    onChanged: filter.updateTimingCategories,
                    selectedDistances: state.distanciasBandas,
                    onDistanceChanged: filter.updateTimingDistance,
                  ),
                ),
                _FilterTile(
                  title: 'Tipo de ciclo',
                  child: const CycleTypeFilter(),
                ),
                _FilterTile(
                  title: 'Score de similaridade',
                  child: const ScoreRangeFilter(),
                ),
                _FilterTile(
                  title: 'Valor do contrato / Remuneração',
                  child: const FinancialThresholdFilter(),
                ),
                _FilterTile(
                  title: 'Órgão',
                  child: SearchableChecklist(
                    title: 'Órgão',
                    allOptions: data.allOrgaos,
                    selected: state.orgaosSelecionados,
                    onChanged: (v) => filter.updateCategorical(orgaos: () => v),
                  ),
                ),
                _FilterTile(
                  title: 'Empresa',
                  child: data.empresasLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : SearchableChecklist(
                          title: 'Empresa',
                          allOptions: data.contextualEmpresas,
                          selected: state.empresasSelecionadas,
                          onChanged: (v) => filter.updateCategorical(empresas: () => v),
                          emptyLabel: 'Nenhuma empresa disponível com os filtros atuais',
                        ),
                ),
                _FilterTile(
                  title: 'Cargo',
                  child: data.cargosLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : SearchableChecklist(
                          title: 'Cargo',
                          allOptions: data.contextualCargos,
                          selected: state.cargosSelecionados,
                          onChanged: (v) => filter.updateCategorical(cargos: () => v),
                          emptyLabel: 'Nenhum cargo disponível com os filtros atuais',
                        ),
                ),
                _FilterTile(
                  title: 'Função',
                  child: data.funcoesLoading
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : SearchableChecklist(
                          title: 'Função',
                          allOptions: data.contextualFuncoes,
                          selected: state.funcoesSelecionadas,
                          onChanged: (v) => filter.updateCategorical(funcoes: () => v),
                          emptyLabel: 'Nenhuma função disponível com os filtros atuais',
                        ),
                ),
                _FilterTile(
                  title: 'Vínculo',
                  child: SearchableChecklist(
                    title: 'Vínculo',
                    allOptions: data.allVinculos,
                    selected: state.vinculosSelecionados,
                    onChanged: (v) => filter.updateCategorical(vinculos: () => v),
                  ),
                ),
                _FilterTile(
                  title: 'Qualificação do sócio',
                  child: SearchableChecklist(
                    title: 'Qualificação',
                    allOptions: data.allQualificacoes,
                    selected: state.qualificacoesSelecionadas,
                    onChanged: (v) =>
                        filter.updateCategorical(qualificacoes: () => v),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _handle() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      );
}

class _FilterTile extends StatelessWidget {
  final String title;
  final Widget child;

  const _FilterTile({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(title, style: Theme.of(context).textTheme.bodyMedium),
      childrenPadding:
          const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      children: [child],
    );
  }
}
