class AnalyticsData {
  final int totalInstancias;
  final DateTime computedAt;

  // Universo Geral
  final int totalCiclos;
  final int totalTriangulos;
  final int totalQuadrados;
  final double pctTriangulos;
  final double pctQuadrados;
  final List<(String, int)> cicloPorOrgao;
  final List<(String, int)> cicloPorVinculo;
  final List<(String, int)> topEmpresas;
  final List<(String, int)> topFuncionarios;

  // Contratos
  final int totalContratosUnicos;
  final int contratosExcluidosValorAusente;
  final double mediaValorContrato;
  final double medianaValorContrato;
  final double desvioPadraoValorContrato;
  final double maxValorContrato;
  final double totalValorMobilizado;
  final List<(String, int)> histogramaValor;
  final int contratosDurante;
  final int contratosApos;
  final int contratosAntes;
  final int contratosTimingDesconhecido;

  // Vínculos
  final int totalVinculosUnicos;
  final List<(String, int)> histogramaDuracao;
  final List<(int, int)> distribuicaoTemporal;
  final Map<String, int> tipoVinculoNasCasos;
  final Map<String, int> tipoVinculoNaFolha;

  const AnalyticsData({
    required this.totalInstancias,
    required this.computedAt,
    required this.totalCiclos,
    required this.totalTriangulos,
    required this.totalQuadrados,
    required this.pctTriangulos,
    required this.pctQuadrados,
    required this.cicloPorOrgao,
    required this.cicloPorVinculo,
    required this.topEmpresas,
    required this.topFuncionarios,
    required this.totalContratosUnicos,
    required this.contratosExcluidosValorAusente,
    required this.mediaValorContrato,
    required this.medianaValorContrato,
    required this.desvioPadraoValorContrato,
    required this.maxValorContrato,
    required this.totalValorMobilizado,
    required this.histogramaValor,
    required this.contratosDurante,
    required this.contratosApos,
    required this.contratosAntes,
    required this.contratosTimingDesconhecido,
    required this.totalVinculosUnicos,
    required this.histogramaDuracao,
    required this.distribuicaoTemporal,
    required this.tipoVinculoNasCasos,
    required this.tipoVinculoNaFolha,
  });

  factory AnalyticsData.empty() => AnalyticsData(
        totalInstancias: 0,
        computedAt: DateTime.now(),
        totalCiclos: 0,
        totalTriangulos: 0,
        totalQuadrados: 0,
        pctTriangulos: 0.0,
        pctQuadrados: 0.0,
        cicloPorOrgao: const [],
        cicloPorVinculo: const [],
        topEmpresas: const [],
        topFuncionarios: const [],
        totalContratosUnicos: 0,
        contratosExcluidosValorAusente: 0,
        mediaValorContrato: 0.0,
        medianaValorContrato: 0.0,
        desvioPadraoValorContrato: 0.0,
        maxValorContrato: 0.0,
        totalValorMobilizado: 0.0,
        histogramaValor: const [],
        contratosDurante: 0,
        contratosApos: 0,
        contratosAntes: 0,
        contratosTimingDesconhecido: 0,
        totalVinculosUnicos: 0,
        histogramaDuracao: const [],
        distribuicaoTemporal: const [],
        tipoVinculoNasCasos: const {},
        tipoVinculoNaFolha: const {},
      );
}
