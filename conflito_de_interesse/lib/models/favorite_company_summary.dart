import 'conflito_record.dart';

class FavoriteCompanySummary {
  final String empresa;
  final String cnpj;
  final int nTriangulos;
  final int nQuadrados;
  final List<ConflittoRecord> sociosFavoritados;

  const FavoriteCompanySummary({
    required this.empresa,
    required this.cnpj,
    required this.nTriangulos,
    required this.nQuadrados,
    required this.sociosFavoritados,
  });

  int get totalRegistros => nTriangulos + nQuadrados;

  String get empresaKey => cnpj.isNotEmpty ? cnpj : empresa;
}
