import '../models/conflito_record.dart';
import '../models/filter_state.dart';

class FilterService {
  List<ConflittoRecord> apply(
    List<ConflittoRecord> all,
    FilterState state,
  ) {
    var result = all.where((r) => _passes(r, state)).toList();
    _sortWith(result, state.sortColumn, state.sortDirection);
    return result;
  }

  List<ConflittoRecord> applyExcludingCategorical(
    List<ConflittoRecord> all,
    FilterState state,
  ) {
    return all.where((r) => _passesExcludingCategorical(r, state)).toList();
  }

  List<ConflittoRecord> sortFavorites(
    List<ConflittoRecord> favorites,
    FilterState state,
  ) {
    final result = List<ConflittoRecord>.from(favorites);
    _sortWith(result, state.favoriteSortColumn, state.favoriteSortDirection);
    return result;
  }

  bool _passes(ConflittoRecord r, FilterState state) {
    // --- Timing category ---
    if (!state.timingCategoriesSelecionadas.contains(r.timingLabel.category)) {
      return false;
    }

    // --- Timing distance (applies only to antes/apos) ---
    if (r.timingLabel.category != TimingCategory.durante) {
      final months = r.timingLabel.months;
      final TimingDistanceBand band;
      if (months <= 12) {
        band = TimingDistanceBand.ate1ano;
      } else if (months <= 24) {
        band = TimingDistanceBand.ate2anos;
      } else if (months <= 36) {
        band = TimingDistanceBand.ate3anos;
      } else {
        band = TimingDistanceBand.mais4anos;
      }
      if (!state.distanciasBandas.contains(band)) return false;
    }

    // --- Cycle type ---
    if (!state.incluiTriangulo && !state.incluiQuadrado) { return false; }
    if (!state.incluiTriangulo && r.tipoCiclo == 'triangulo') { return false; }
    if (!state.incluiQuadrado && r.tipoCiclo == 'quadrado') { return false; }

    // --- Score (only for quadrado) ---
    if (state.incluiQuadrado && r.tipoCiclo == 'quadrado') {
      if (r.scoreMatch < state.scoreMin || r.scoreMatch > state.scoreMax) {
        return false;
      }
    }

    // --- Financial ---
    if (r.valorContrato < state.valorContratoMin ||
        r.valorContrato > state.valorContratoMax) {
      return false;
    }
    if (r.remuneracaoTotal < state.remuneracaoMin ||
        r.remuneracaoTotal > state.remuneracaoMax) {
      return false;
    }

    // --- Categorical ---
    // null = no filter (all pass); empty set = nothing passes
    if (state.orgaosSelecionados != null &&
        !state.orgaosSelecionados!.contains(r.orgao)) {
      return false;
    }
    if (state.empresasSelecionadas != null &&
        !state.empresasSelecionadas!.contains(r.empresa)) {
      return false;
    }
    if (state.cargosSelecionados != null &&
        !state.cargosSelecionados!.contains(r.cargo)) {
      return false;
    }
    if (state.vinculosSelecionados != null &&
        !state.vinculosSelecionados!.contains(r.vinculo)) {
      return false;
    }
    if (state.qualificacoesSelecionadas != null &&
        !state.qualificacoesSelecionadas!.contains(r.qualificacaoSocio)) {
      return false;
    }
    if (state.funcoesSelecionadas != null) {
      final funcaoKey = r.funcao ?? 'NULL';
      if (!state.funcoesSelecionadas!.contains(funcaoKey)) { return false; }
    }

    // --- Name search ---
    if (state.buscaNome.isNotEmpty) {
      final q = state.buscaNome.toLowerCase();
      if (!r.funcionario.toLowerCase().contains(q) &&
          !r.socio.toLowerCase().contains(q)) {
        return false;
      }
    }

    return true;
  }

  bool _passesExcludingCategorical(ConflittoRecord r, FilterState state) {
    if (!state.timingCategoriesSelecionadas.contains(r.timingLabel.category)) {
      return false;
    }
    if (r.timingLabel.category != TimingCategory.durante) {
      final months = r.timingLabel.months;
      final TimingDistanceBand band;
      if (months <= 12) {
        band = TimingDistanceBand.ate1ano;
      } else if (months <= 24) {
        band = TimingDistanceBand.ate2anos;
      } else if (months <= 36) {
        band = TimingDistanceBand.ate3anos;
      } else {
        band = TimingDistanceBand.mais4anos;
      }
      if (!state.distanciasBandas.contains(band)) return false;
    }
    if (!state.incluiTriangulo && !state.incluiQuadrado) return false;
    if (!state.incluiTriangulo && r.tipoCiclo == 'triangulo') return false;
    if (!state.incluiQuadrado && r.tipoCiclo == 'quadrado') return false;
    if (state.incluiQuadrado && r.tipoCiclo == 'quadrado') {
      if (r.scoreMatch < state.scoreMin || r.scoreMatch > state.scoreMax) {
        return false;
      }
    }
    if (r.valorContrato < state.valorContratoMin ||
        r.valorContrato > state.valorContratoMax) {
      return false;
    }
    if (r.remuneracaoTotal < state.remuneracaoMin ||
        r.remuneracaoTotal > state.remuneracaoMax) {
      return false;
    }
    if (state.orgaosSelecionados != null &&
        !state.orgaosSelecionados!.contains(r.orgao)) {
      return false;
    }
    if (state.vinculosSelecionados != null &&
        !state.vinculosSelecionados!.contains(r.vinculo)) {
      return false;
    }
    if (state.qualificacoesSelecionadas != null &&
        !state.qualificacoesSelecionadas!.contains(r.qualificacaoSocio)) {
      return false;
    }
    if (state.buscaNome.isNotEmpty) {
      final q = state.buscaNome.toLowerCase();
      if (!r.funcionario.toLowerCase().contains(q) &&
          !r.socio.toLowerCase().contains(q)) {
        return false;
      }
    }
    return true;
  }

  void _sortWith(
    List<ConflittoRecord> list,
    SortColumn column,
    SortDirection direction,
  ) {
    if (column == SortColumn.none) return;
    list.sort((a, b) {
      int cmp;
      switch (column) {
        case SortColumn.funcionario:
          cmp = a.funcionario.compareTo(b.funcionario);
          if (cmp == 0) cmp = -a.dataContrato.compareTo(b.dataContrato);
          if (cmp == 0) cmp = _temporalityCmp(a, b);
          return direction == SortDirection.asc ? cmp : -cmp;
        case SortColumn.temporalidade:
          final aMonths = a.timingLabel.months;
          final bMonths = b.timingLabel.months;
          final aCat = _catOrder(a.timingLabel.category);
          final bCat = _catOrder(b.timingLabel.category);
          if (direction == SortDirection.asc) {
            cmp = aMonths != bMonths ? aMonths.compareTo(bMonths) : aCat.compareTo(bCat);
          } else {
            cmp = aMonths != bMonths ? bMonths.compareTo(aMonths) : bCat.compareTo(aCat);
          }
          return cmp;
        case SortColumn.valorContrato:
          cmp = a.valorContrato.compareTo(b.valorContrato);
        case SortColumn.scoreMatch:
          cmp = a.scoreMatch.compareTo(b.scoreMatch);
        case SortColumn.none:
          return 0;
      }
      final directed = direction == SortDirection.asc ? cmp : -cmp;
      if (directed == 0) return _temporalityCmp(a, b);
      return directed;
    });
  }

  int _catOrder(TimingCategory c) {
    if (c == TimingCategory.durante) return 0;
    if (c == TimingCategory.apos) return 1;
    return 2;
  }

  int _temporalityCmp(ConflittoRecord a, ConflittoRecord b) {
    final aMonths = a.timingLabel.months;
    final bMonths = b.timingLabel.months;
    if (aMonths != bMonths) return aMonths.compareTo(bMonths);
    return _catOrder(a.timingLabel.category).compareTo(_catOrder(b.timingLabel.category));
  }
}
