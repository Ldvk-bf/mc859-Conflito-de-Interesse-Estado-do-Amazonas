import 'package:flutter/foundation.dart';
import '../models/conflito_record.dart';
import '../models/filter_state.dart';
import '../models/favorite_company_summary.dart';
import '../models/favorite_orgao_summary.dart';
import '../services/anonymization_service.dart';
import '../services/csv_parser_service.dart';
import '../services/filter_service.dart';
import '../services/favorites_service.dart';
import '../services/export_basket_service.dart';

class DataProvider extends ChangeNotifier {
  final CsvParserService _parser = CsvParserService();
  final FilterService _filterService = FilterService();
  final FavoritesService favoritesService = FavoritesService();
  final ExportBasketService exportBasketService = ExportBasketService();

  List<ConflittoRecord> _allRecords = [];
  List<ConflittoRecord> _filteredRecords = [];
  FilterState _filterState = FilterState.defaults();
  bool _loading = true;
  int _filterVersion = 0;

  bool _anonymized = true;
  final Map<String, String> _codeMap = {};

  Set<String> _contextualCargos = {};
  Set<String> _contextualFuncoes = {};
  Set<String> _contextualEmpresas = {};
  bool _cargosLoading = false;
  bool _funcoesLoading = false;
  bool _empresasLoading = false;
  Set<String>? _invalidatedCargos;
  Set<String>? _invalidatedEmpresas;

  List<ConflittoRecord> get allRecords => _allRecords;
  List<ConflittoRecord> get filteredRecords => _filteredRecords;
  bool get loading => _loading;
  int get filterVersion => _filterVersion;
  bool get anonymized => _anonymized;

  void toggleAnonymization() {
    _anonymized = !_anonymized;
    notifyListeners();
  }

  String displayName(String name, String type) {
    if (name.isEmpty) return '$type-??????';
    final code = _codeMap['$type:${AnonymizationService.normalize(name)}'] ?? '$type-??????';
    return _anonymized ? code : name;
  }

  void _buildCodeMap() {
    _buildCodesForType(
      _allRecords.map((r) => r.funcionario).where((n) => n.isNotEmpty).toSet(),
      'FUNC',
    );
    _buildCodesForType(
      _allRecords.map((r) => r.socio).where((n) => n.isNotEmpty).toSet(),
      'SOC',
    );
  }

  void _buildCodesForType(Set<String> names, String prefix) {
    final byHash = <int, List<String>>{};
    for (final name in names) {
      final normalized = AnonymizationService.normalize(name);
      final h = AnonymizationService.hash(normalized) & 0xFFFFFF;
      byHash.putIfAbsent(h, () => []).add(name);
    }
    for (final entry in byHash.entries) {
      final hex = AnonymizationService.hexCode(entry.key);
      final sorted = entry.value..sort();
      for (int i = 0; i < sorted.length; i++) {
        final normalized = AnonymizationService.normalize(sorted[i]);
        _codeMap['$prefix:$normalized'] = i == 0 ? '$prefix-$hex' : '$prefix-$hex$i';
      }
    }
  }

  Set<String> get contextualCargos => _contextualCargos;
  Set<String> get contextualFuncoes => _contextualFuncoes;
  Set<String> get contextualEmpresas => _contextualEmpresas;
  bool get cargosLoading => _cargosLoading;
  bool get funcoesLoading => _funcoesLoading;
  bool get empresasLoading => _empresasLoading;
  Set<String>? get invalidatedCargos => _invalidatedCargos;
  Set<String>? get invalidatedEmpresas => _invalidatedEmpresas;

  double get maxValorContrato =>
      _allRecords.isEmpty ? 196489860.0 : _allRecords.map((r) => r.valorContrato).reduce((a, b) => a > b ? a : b);
  double get maxRemuneracao =>
      _allRecords.isEmpty ? 133139.43 : _allRecords.map((r) => r.remuneracaoTotal).reduce((a, b) => a > b ? a : b);

  Set<String> get allOrgaos => _allRecords.map((r) => r.orgao).toSet();
  Set<String> get allCargos => _allRecords.map((r) => r.cargo).toSet();
  Set<String> get allFuncoes => {
    ..._allRecords.map((r) => r.funcao ?? 'NULL'),
  };
  Set<String> get allVinculos => _allRecords.map((r) => r.vinculo).toSet();
  Set<String> get allQualificacoes =>
      _allRecords.map((r) => r.qualificacaoSocio).toSet();

  List<ConflittoRecord> get favoriteRecords => _allRecords
      .where((r) => favoritesService.contains(r.favoriteKey))
      .toList();

  List<ConflittoRecord> get basketRecords =>
      _allRecords.where((r) => exportBasketService.contains(r.index)).toList();

  int get basketCount => exportBasketService.count;

  bool isInBasket(int index) => exportBasketService.contains(index);

  List<FavoriteCompanySummary> get favoriteCompanies {
    final favs = favoriteRecords;
    if (favs.isEmpty) return [];
    final keys = <String>{};
    for (final r in favs) {
      keys.add(r.cnpj.isNotEmpty ? r.cnpj : r.empresa);
    }
    final result = <FavoriteCompanySummary>[];
    for (final key in keys) {
      final allForKey = _allRecords.where(
        (r) => (r.cnpj.isNotEmpty ? r.cnpj : r.empresa) == key,
      ).toList();
      final favsForKey = favs.where(
        (r) => (r.cnpj.isNotEmpty ? r.cnpj : r.empresa) == key,
      ).toList();
      result.add(FavoriteCompanySummary(
        empresa: allForKey.first.empresa,
        cnpj: allForKey.first.cnpj,
        nTriangulos: allForKey.where((r) => r.tipoCiclo == 'triangulo').length,
        nQuadrados: allForKey.where((r) => r.tipoCiclo == 'quadrado').length,
        sociosFavoritados: favsForKey,
      ));
    }
    result.sort((a, b) => a.empresa.compareTo(b.empresa));
    return result;
  }

  List<FavoriteOrgaoSummary> get favoriteOrgaos {
    final favs = favoriteRecords;
    if (favs.isEmpty) return [];
    final orgaos = favs.map((r) => r.orgao).toSet();
    final result = orgaos.map((orgao) => FavoriteOrgaoSummary(
      orgao: orgao,
      nRegistros: _allRecords.where((r) => r.orgao == orgao).length,
      nFavoritados: favs.where((r) => r.orgao == orgao).length,
    )).toList();
    result.sort((a, b) => a.orgao.compareTo(b.orgao));
    return result;
  }

  List<ConflittoRecord> recordsForCompany(String empresaKey) {
    final result = _allRecords.where((r) {
      final key = r.cnpj.isNotEmpty ? r.cnpj : r.empresa;
      return key == empresaKey;
    }).toList();
    result.sort((a, b) => a.funcionario.compareTo(b.funcionario));
    return result;
  }

  List<ConflittoRecord> recordsForOrgao(String orgao) {
    final result = _allRecords.where((r) => r.orgao == orgao).toList();
    result.sort((a, b) => a.funcionario.compareTo(b.funcionario));
    return result;
  }

  bool isFavorite(String key) => favoritesService.contains(key);

  Future<void> toggleFavorite(String key) async {
    await favoritesService.toggle(key);
    notifyListeners();
  }

  Future<void> addToBasket(int index) async {
    await exportBasketService.add(index);
    notifyListeners();
  }

  Future<void> removeFromBasket(int index) async {
    await exportBasketService.remove(index);
    notifyListeners();
  }

  Future<void> clearBasket() async {
    await exportBasketService.clear();
    notifyListeners();
  }

  void clearInvalidatedCargos() {
    _invalidatedCargos = null;
  }

  void clearInvalidatedEmpresas() {
    _invalidatedEmpresas = null;
  }

  @visibleForTesting
  void loadTestRecords(List<ConflittoRecord> records) {
    _allRecords = records;
    _buildCodeMap();
  }

  Future<void> init() async {
    await favoritesService.loadAll();
    await exportBasketService.loadAll();
    _allRecords = await _parser.load();
    _filterState = FilterState.defaults(
      valorContratoMax: maxValorContrato,
      remuneracaoMax: maxRemuneracao,
    );
    _applyFilter();
    final subset = _filterService.applyExcludingCategorical(_allRecords, _filterState);
    _contextualCargos = subset.map((r) => r.cargo).toSet();
    _contextualFuncoes = subset.map((r) => r.funcao ?? 'NULL').toSet();
    _contextualEmpresas = subset.map((r) => r.empresa).toSet();
    _buildCodeMap();
    _loading = false;
    notifyListeners();
  }

  void applyFilter(FilterState state) {
    _filterState = state;
    _filterVersion++;
    _applyFilter();
    _cargosLoading = true;
    _funcoesLoading = true;
    _empresasLoading = true;
    notifyListeners();
    Future.microtask(_computeContextualFilters);
  }

  void _applyFilter() {
    _filteredRecords = _filterService.apply(_allRecords, _filterState);
  }

  Future<void> _computeContextualFilters() async {
    final subset = _filterService.applyExcludingCategorical(_allRecords, _filterState);
    final newCargos = subset.map((r) => r.cargo).toSet();
    final newFuncoes = subset.map((r) => r.funcao ?? 'NULL').toSet();
    final newEmpresas = subset.map((r) => r.empresa).toSet();

    if (_filterState.cargosSelecionados != null) {
      final invalid = _filterState.cargosSelecionados!
          .where((c) => !newCargos.contains(c))
          .toSet();
      if (invalid.isNotEmpty) _invalidatedCargos = invalid;
    }

    if (_filterState.empresasSelecionadas != null) {
      final invalid = _filterState.empresasSelecionadas!
          .where((e) => !newEmpresas.contains(e))
          .toSet();
      if (invalid.isNotEmpty) _invalidatedEmpresas = invalid;
    }

    _contextualCargos = newCargos;
    _contextualFuncoes = newFuncoes;
    _contextualEmpresas = newEmpresas;
    _cargosLoading = false;
    _funcoesLoading = false;
    _empresasLoading = false;
    notifyListeners();
  }
}
