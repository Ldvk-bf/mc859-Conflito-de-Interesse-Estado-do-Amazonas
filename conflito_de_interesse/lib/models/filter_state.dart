import 'conflito_record.dart';

enum SortColumn { none, funcionario, valorContrato, scoreMatch, temporalidade }

enum SortDirection { asc, desc }

enum TimingDistanceBand { ate1ano, ate2anos, ate3anos, mais4anos }

class FilterState {
  final Set<TimingCategory> timingCategoriesSelecionadas;
  final double valorContratoMin;
  final double valorContratoMax;
  final double remuneracaoMin;
  final double remuneracaoMax;
  final bool incluiTriangulo;
  final bool incluiQuadrado;
  final double scoreMin;
  final double scoreMax;
  // null = no filter (all pass); {} = nothing passes; non-empty = only matching pass
  final Set<String>? orgaosSelecionados;
  final Set<String>? empresasSelecionadas;
  final Set<String>? cargosSelecionados;
  final Set<String>? funcoesSelecionadas;
  final Set<String>? vinculosSelecionados;
  final Set<String>? qualificacoesSelecionadas;
  final Set<TimingDistanceBand> distanciasBandas;
  final String buscaNome;
  final SortColumn sortColumn;
  final SortDirection sortDirection;
  final SortColumn favoriteSortColumn;
  final SortDirection favoriteSortDirection;

  const FilterState({
    required this.timingCategoriesSelecionadas,
    required this.valorContratoMin,
    required this.valorContratoMax,
    required this.remuneracaoMin,
    required this.remuneracaoMax,
    required this.incluiTriangulo,
    required this.incluiQuadrado,
    required this.scoreMin,
    required this.scoreMax,
    required this.orgaosSelecionados,
    required this.empresasSelecionadas,
    required this.cargosSelecionados,
    required this.funcoesSelecionadas,
    required this.vinculosSelecionados,
    required this.qualificacoesSelecionadas,
    required this.distanciasBandas,
    required this.buscaNome,
    required this.sortColumn,
    required this.sortDirection,
    required this.favoriteSortColumn,
    required this.favoriteSortDirection,
  });

  factory FilterState.defaults({
    double valorContratoMax = 196489860.0,
    double remuneracaoMax = 133139.43,
  }) {
    return FilterState(
      timingCategoriesSelecionadas: TimingCategory.values.toSet(),
      valorContratoMin: 0,
      valorContratoMax: valorContratoMax,
      remuneracaoMin: 0,
      remuneracaoMax: remuneracaoMax,
      incluiTriangulo: true,
      incluiQuadrado: true,
      scoreMin: 92,
      scoreMax: 100,
      orgaosSelecionados: null,
      empresasSelecionadas: null,
      cargosSelecionados: null,
      funcoesSelecionadas: null,
      vinculosSelecionados: null,
      qualificacoesSelecionadas: null,
      distanciasBandas: TimingDistanceBand.values.toSet(),
      buscaNome: '',
      sortColumn: SortColumn.scoreMatch,
      sortDirection: SortDirection.desc,
      favoriteSortColumn: SortColumn.scoreMatch,
      favoriteSortDirection: SortDirection.desc,
    );
  }

  FilterState copyWith({
    Set<TimingCategory>? timingCategoriesSelecionadas,
    double? valorContratoMin,
    double? valorContratoMax,
    double? remuneracaoMin,
    double? remuneracaoMax,
    bool? incluiTriangulo,
    bool? incluiQuadrado,
    double? scoreMin,
    double? scoreMax,
    Set<String>? Function()? orgaosSelecionados,
    Set<String>? Function()? empresasSelecionadas,
    Set<String>? Function()? cargosSelecionados,
    Set<String>? Function()? funcoesSelecionadas,
    Set<String>? Function()? vinculosSelecionados,
    Set<String>? Function()? qualificacoesSelecionadas,
    Set<TimingDistanceBand>? distanciasBandas,
    String? buscaNome,
    SortColumn? sortColumn,
    SortDirection? sortDirection,
    SortColumn? favoriteSortColumn,
    SortDirection? favoriteSortDirection,
  }) {
    return FilterState(
      timingCategoriesSelecionadas:
          timingCategoriesSelecionadas ?? this.timingCategoriesSelecionadas,
      valorContratoMin: valorContratoMin ?? this.valorContratoMin,
      valorContratoMax: valorContratoMax ?? this.valorContratoMax,
      remuneracaoMin: remuneracaoMin ?? this.remuneracaoMin,
      remuneracaoMax: remuneracaoMax ?? this.remuneracaoMax,
      incluiTriangulo: incluiTriangulo ?? this.incluiTriangulo,
      incluiQuadrado: incluiQuadrado ?? this.incluiQuadrado,
      scoreMin: scoreMin ?? this.scoreMin,
      scoreMax: scoreMax ?? this.scoreMax,
      orgaosSelecionados:
          orgaosSelecionados != null ? orgaosSelecionados() : this.orgaosSelecionados,
      empresasSelecionadas:
          empresasSelecionadas != null ? empresasSelecionadas() : this.empresasSelecionadas,
      cargosSelecionados:
          cargosSelecionados != null ? cargosSelecionados() : this.cargosSelecionados,
      funcoesSelecionadas:
          funcoesSelecionadas != null ? funcoesSelecionadas() : this.funcoesSelecionadas,
      vinculosSelecionados:
          vinculosSelecionados != null ? vinculosSelecionados() : this.vinculosSelecionados,
      qualificacoesSelecionadas:
          qualificacoesSelecionadas != null
              ? qualificacoesSelecionadas()
              : this.qualificacoesSelecionadas,
      distanciasBandas: distanciasBandas ?? this.distanciasBandas,
      buscaNome: buscaNome ?? this.buscaNome,
      sortColumn: sortColumn ?? this.sortColumn,
      sortDirection: sortDirection ?? this.sortDirection,
      favoriteSortColumn: favoriteSortColumn ?? this.favoriteSortColumn,
      favoriteSortDirection: favoriteSortDirection ?? this.favoriteSortDirection,
    );
  }

  bool get hasActiveFilters =>
      timingCategoriesSelecionadas.length < TimingCategory.values.length ||
      distanciasBandas.length < TimingDistanceBand.values.length ||
      orgaosSelecionados != null ||
      empresasSelecionadas != null ||
      cargosSelecionados != null ||
      funcoesSelecionadas != null ||
      vinculosSelecionados != null ||
      qualificacoesSelecionadas != null ||
      buscaNome.isNotEmpty ||
      !(incluiTriangulo && incluiQuadrado);
}

class FilterResult {
  final List<dynamic> records;
  final int totalCount;
  final int filteredCount;

  const FilterResult({
    required this.records,
    required this.totalCount,
    required this.filteredCount,
  });
}
