import 'package:flutter/foundation.dart';
import '../models/conflito_record.dart';
import '../models/filter_state.dart';
import 'data_provider.dart';

class FilterProvider extends ChangeNotifier {
  final DataProvider _data;
  late FilterState _state;

  FilterProvider(this._data) {
    _state = FilterState.defaults(
      valorContratoMax: _data.maxValorContrato,
      remuneracaoMax: _data.maxRemuneracao,
    );
  }

  FilterState get state => _state;

  void _update(FilterState next) {
    _state = next;
    _data.applyFilter(_state);
    notifyListeners();
  }

  void reset() {
    _update(FilterState.defaults(
      valorContratoMax: _data.maxValorContrato,
      remuneracaoMax: _data.maxRemuneracao,
    ));
  }

  void updateTimingCategories(Set<TimingCategory> cats) =>
      _update(_state.copyWith(timingCategoriesSelecionadas: cats));

  void updateTimingDistance(Set<TimingDistanceBand> bandas) =>
      _update(_state.copyWith(distanciasBandas: bandas));

  void updateCycleAndScore({
    bool? triangulo,
    bool? quadrado,
    double? scoreMin,
    double? scoreMax,
  }) {
    final newTri = triangulo ?? _state.incluiTriangulo;
    final newQuad = quadrado ?? _state.incluiQuadrado;
    if (!newTri && !newQuad) { return; }
    _update(_state.copyWith(
      incluiTriangulo: newTri,
      incluiQuadrado: newQuad,
      scoreMin: scoreMin,
      scoreMax: scoreMax,
    ));
  }

  void updateFinancial({
    double? valorMin,
    double? valorMax,
    double? remMin,
    double? remMax,
  }) =>
      _update(_state.copyWith(
        valorContratoMin: valorMin,
        valorContratoMax: valorMax,
        remuneracaoMin: remMin,
        remuneracaoMax: remMax,
      ));

  void updateCategorical({
    Set<String>? Function()? orgaos,
    Set<String>? Function()? empresas,
    Set<String>? Function()? cargos,
    Set<String>? Function()? funcoes,
    Set<String>? Function()? vinculos,
    Set<String>? Function()? qualificacoes,
  }) =>
      _update(_state.copyWith(
        orgaosSelecionados: orgaos,
        empresasSelecionadas: empresas,
        cargosSelecionados: cargos,
        funcoesSelecionadas: funcoes,
        vinculosSelecionados: vinculos,
        qualificacoesSelecionadas: qualificacoes,
      ));

  void updateNameSearch(String q) => _update(_state.copyWith(buscaNome: q));

  void updateSort(SortColumn col) {
    final dir = (_state.sortColumn == col && _state.sortDirection == SortDirection.asc)
        ? SortDirection.desc
        : SortDirection.asc;
    _update(_state.copyWith(sortColumn: col, sortDirection: dir));
  }

  void updateFavoriteSort(SortColumn col) {
    final dir = (_state.favoriteSortColumn == col &&
            _state.favoriteSortDirection == SortDirection.asc)
        ? SortDirection.desc
        : SortDirection.asc;
    _update(_state.copyWith(favoriteSortColumn: col, favoriteSortDirection: dir));
  }
}
