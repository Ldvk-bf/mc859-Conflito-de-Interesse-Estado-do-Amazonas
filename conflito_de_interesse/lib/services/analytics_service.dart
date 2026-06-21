import 'dart:math';
import '../models/conflito_record.dart';
import '../models/analytics_data.dart';

class AnalyticsService {
  static String _normalize(String s) =>
      s.trim().toUpperCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _contractKey(ConflittoRecord r) {
    final id = r.cnpj.isNotEmpty ? r.cnpj : r.empresa;
    return '$id|${r.dataContrato.toIso8601String()}';
  }

  static String _employeeKey(ConflittoRecord r) {
    final fim = r.periodoFim?.toIso8601String() ?? 'ativo';
    return '${_normalize(r.funcionario)}|${r.periodoInicio.toIso8601String()}|$fim';
  }

  static String _vinculoKey(ConflittoRecord r) {
    final fim = r.periodoFim?.toIso8601String() ?? 'ativo';
    return '${_normalize(r.funcionario)}|${r.orgao}|${r.periodoInicio.toIso8601String()}|$fim';
  }

  static String _companyKey(ConflittoRecord r) =>
      r.cnpj.isNotEmpty ? r.cnpj : _normalize(r.empresa);

  static String _normalizeVinculo(String v) {
    final u = v.toUpperCase();
    if (u.contains('ESTATUT')) return 'Estatutário';
    if (u.contains('TEMPOR')) return 'Temporário';
    if (u.contains('CELET')) return 'Celetista';
    if (u.contains('COMISS')) return 'Comissionado';
    return 'Outros';
  }

  static AnalyticsData compute(
    ({List<ConflittoRecord> filtered, List<ConflittoRecord> all}) args,
  ) {
    final filtered = args.filtered;
    final all = args.all;

    if (filtered.isEmpty) return AnalyticsData.empty();

    // 1. Deduplicate contracts
    final uniqueContracts = <String, ConflittoRecord>{};
    for (final r in filtered) {
      uniqueContracts.putIfAbsent(_contractKey(r), () => r);
    }

    // 2. Deduplicate vínculos from filtered
    final uniqueVinculos = <String, ConflittoRecord>{};
    for (final r in filtered) {
      uniqueVinculos.putIfAbsent(_vinculoKey(r), () => r);
    }

    // 3. Deduplicate vínculos from all (reference baseline)
    final allVinculos = <String, ConflittoRecord>{};
    for (final r in all) {
      allVinculos.putIfAbsent(_vinculoKey(r), () => r);
    }

    // 4. Universo metrics
    int totalTriangulos = 0;
    int totalQuadrados = 0;
    final orgaoCount = <String, int>{};
    for (final r in filtered) {
      if (r.tipoCiclo == 'triangulo') totalTriangulos++;
      if (r.tipoCiclo == 'quadrado') totalQuadrados++;
      orgaoCount[r.orgao] = (orgaoCount[r.orgao] ?? 0) + 1;
    }
    final totalCiclos = filtered.length;
    final pctTriangulos = totalCiclos > 0 ? totalTriangulos / totalCiclos * 100 : 0.0;
    final pctQuadrados = totalCiclos > 0 ? totalQuadrados / totalCiclos * 100 : 0.0;

    final cicloPorOrgao = orgaoCount.entries
        .map((e) => (e.key, e.value))
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    // cicloPorVinculo: count per normalized vínculo type from unique vínculos
    final vinculoCount = <String, int>{};
    for (final r in uniqueVinculos.values) {
      final type = _normalizeVinculo(r.vinculo);
      vinculoCount[type] = (vinculoCount[type] ?? 0) + 1;
    }
    final cicloPorVinculo = vinculoCount.entries
        .map((e) => (e.key, e.value))
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));

    // 4. Top 10 empresas: distinct employee keys per company
    final companyEmployees = <String, Set<String>>{};
    final companyName = <String, String>{};
    for (final r in filtered) {
      final ck = _companyKey(r);
      companyEmployees.putIfAbsent(ck, () => <String>{}).add(_employeeKey(r));
      companyName[ck] = r.empresa;
    }
    final topEmpresas = companyEmployees.entries
        .map((e) => (companyName[e.key]!, e.value.length))
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final top10Empresas = topEmpresas.take(10).toList();

    // Top 10 funcionários: row count per employee key
    final employeeRowCount = <String, int>{};
    final employeeName = <String, String>{};
    for (final r in filtered) {
      final ek = _employeeKey(r);
      employeeRowCount[ek] = (employeeRowCount[ek] ?? 0) + 1;
      employeeName[ek] = r.funcionario;
    }
    final topFuncionarios = employeeRowCount.entries
        .map((e) => (employeeName[e.key]!, e.value))
        .toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final top10Funcionarios = topFuncionarios.take(10).toList();

    // 6. Contract financial stats (excluding valorContrato == 0)
    final contractValues = <double>[];
    int contratosExcluidosValorAusente = 0;
    for (final r in uniqueContracts.values) {
      if (r.valorContrato == 0.0) {
        contratosExcluidosValorAusente++;
      } else {
        contractValues.add(r.valorContrato);
      }
    }
    contractValues.sort();

    double mediaValor = 0.0;
    double medianaValor = 0.0;
    double desvioValor = 0.0;
    double maxValor = 0.0;
    double totalValorMobilizado = 0.0;

    if (contractValues.isNotEmpty) {
      totalValorMobilizado = contractValues.fold(0.0, (a, b) => a + b);
      mediaValor = totalValorMobilizado / contractValues.length;
      final mid = contractValues.length ~/ 2;
      medianaValor = contractValues.length.isOdd
          ? contractValues[mid]
          : (contractValues[mid - 1] + contractValues[mid]) / 2;
      final variance = contractValues
          .map((v) => pow(v - mediaValor, 2))
          .fold(0.0, (a, b) => a + b) / contractValues.length;
      desvioValor = sqrt(variance);
      maxValor = contractValues.last;
    }

    // 7. Value histogram (non-zero unique contracts)
    int bin0to50k = 0;
    int bin50kto200k = 0;
    int bin200kto1m = 0;
    int bin1mto5m = 0;
    int bin5mPlus = 0;
    for (final v in contractValues) {
      if (v < 50000) {
        bin0to50k++;
      } else if (v < 200000) {
        bin50kto200k++;
      } else if (v < 1000000) {
        bin200kto1m++;
      } else if (v < 5000000) {
        bin1mto5m++;
      } else {
        bin5mPlus++;
      }
    }
    final histogramaValor = [
      ('R\$0–50mil', bin0to50k),
      ('R\$50mil–200mil', bin50kto200k),
      ('R\$200mil–1mi', bin200kto1m),
      ('R\$1mi–5mi', bin1mto5m),
      ('R\$5mi+', bin5mPlus),
    ];

    // 8. Timing proportions from unique contracts
    int contratosDurante = 0;
    int contratosApos = 0;
    int contratosAntes = 0;
    int contratosTimingDesconhecido = 0;
    for (final r in uniqueContracts.values) {
      switch (r.timingLabel.category) {
        case TimingCategory.durante:
          contratosDurante++;
        case TimingCategory.apos:
          contratosApos++;
        case TimingCategory.antes:
          contratosAntes++;
      }
    }
    // Records with sentinel date (DateTime(2000)) for both periodoInicio and dataContrato
    // are still counted by timingLabel; timing unknown is not applicable here per contract.

    // 9. Duration histogram from unique vínculos
    int durBin0to1 = 0;
    int durBin1to3 = 0;
    int durBin3to5 = 0;
    int durBin5plus = 0;
    for (final r in uniqueVinculos.values) {
      final fim = r.periodoFim ?? DateTime.now();
      final years = fim.difference(r.periodoInicio).inDays / 365.25;
      if (years < 1) {
        durBin0to1++;
      } else if (years < 3) {
        durBin1to3++;
      } else if (years < 5) {
        durBin3to5++;
      } else {
        durBin5plus++;
      }
    }
    final histogramaDuracao = [
      ('0–1a', durBin0to1),
      ('1–3a', durBin1to3),
      ('3–5a', durBin3to5),
      ('5+a', durBin5plus),
    ];

    // 10. Temporal distribution: dataContrato.year → count per filtered row
    final yearCount = <int, int>{};
    for (final r in filtered) {
      yearCount[r.dataContrato.year] = (yearCount[r.dataContrato.year] ?? 0) + 1;
    }
    final distribuicaoTemporal = yearCount.entries
        .map((e) => (e.key, e.value))
        .toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));

    // 11. Vínculo type maps
    final tipoVinculoNasCasos = <String, int>{};
    for (final r in uniqueVinculos.values) {
      final type = _normalizeVinculo(r.vinculo);
      tipoVinculoNasCasos[type] = (tipoVinculoNasCasos[type] ?? 0) + 1;
    }
    final tipoVinculoNaFolha = <String, int>{};
    for (final r in allVinculos.values) {
      final type = _normalizeVinculo(r.vinculo);
      tipoVinculoNaFolha[type] = (tipoVinculoNaFolha[type] ?? 0) + 1;
    }

    return AnalyticsData(
      totalInstancias: filtered.length,
      computedAt: DateTime.now(),
      totalCiclos: totalCiclos,
      totalTriangulos: totalTriangulos,
      totalQuadrados: totalQuadrados,
      pctTriangulos: pctTriangulos,
      pctQuadrados: pctQuadrados,
      cicloPorOrgao: cicloPorOrgao,
      cicloPorVinculo: cicloPorVinculo,
      topEmpresas: top10Empresas,
      topFuncionarios: top10Funcionarios,
      totalContratosUnicos: uniqueContracts.length,
      contratosExcluidosValorAusente: contratosExcluidosValorAusente,
      mediaValorContrato: mediaValor,
      medianaValorContrato: medianaValor,
      desvioPadraoValorContrato: desvioValor,
      maxValorContrato: maxValor,
      totalValorMobilizado: totalValorMobilizado,
      histogramaValor: histogramaValor,
      contratosDurante: contratosDurante,
      contratosApos: contratosApos,
      contratosAntes: contratosAntes,
      contratosTimingDesconhecido: contratosTimingDesconhecido,
      totalVinculosUnicos: uniqueVinculos.length,
      histogramaDuracao: histogramaDuracao,
      distribuicaoTemporal: distribuicaoTemporal,
      tipoVinculoNasCasos: tipoVinculoNasCasos,
      tipoVinculoNaFolha: tipoVinculoNaFolha,
    );
  }
}
