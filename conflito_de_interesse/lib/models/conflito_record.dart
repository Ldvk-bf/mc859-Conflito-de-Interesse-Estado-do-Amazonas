import 'dart:convert';

enum TimingCategory { durante, antes, apos }

class TimingLabel {
  final TimingCategory category;
  final int months;

  const TimingLabel({required this.category, required this.months});

  String get displayText {
    if (category == TimingCategory.durante) return 'Durante o vínculo';
    final years = months ~/ 12;
    final rem = months % 12;
    final suffix = category == TimingCategory.antes ? 'antes do vínculo' : 'após o vínculo';
    if (years == 0) return '$rem ${rem == 1 ? "mês" : "meses"} $suffix';
    if (rem == 0) return '$years ${years == 1 ? "ano" : "anos"} $suffix';
    return '$years ${years == 1 ? "ano" : "anos"} e $rem ${rem == 1 ? "mês" : "meses"} $suffix';
  }

  String get compactText {
    if (category == TimingCategory.durante) return 'Durante';
    final years = months ~/ 12;
    final rem = months % 12;
    final suffix = category == TimingCategory.antes ? 'antes' : 'após';
    if (years == 0) return '${rem}m $suffix';
    if (rem == 0) return '${years}a $suffix';
    return '${years}a ${rem}m $suffix';
  }
}

class ConflittoRecord {
  final int index;
  final String tipoCiclo;
  final String funcionario;
  final String socio;
  final double scoreMatch;
  final String metodoMatch;
  final String orgao;
  final String empresa;
  final String cnpj;
  final String cargo;
  final String? funcao;
  final String vinculo;
  final String lotacao;
  final double remuneracaoTotal;
  final DateTime periodoInicio;
  final DateTime? periodoFim;
  final DateTime dataContrato;
  final double valorContrato;
  final String descricao;
  final String qualificacaoSocio;
  final String favoriteKey;

  const ConflittoRecord({
    required this.index,
    required this.tipoCiclo,
    required this.funcionario,
    required this.socio,
    required this.scoreMatch,
    required this.metodoMatch,
    required this.orgao,
    required this.empresa,
    required this.cnpj,
    required this.cargo,
    this.funcao,
    required this.vinculo,
    required this.lotacao,
    required this.remuneracaoTotal,
    required this.periodoInicio,
    this.periodoFim,
    required this.dataContrato,
    required this.valorContrato,
    required this.descricao,
    required this.qualificacaoSocio,
    required this.favoriteKey,
  });

  static String _buildKey(String funcionario, String cnpj, String dataContrato) {
    final raw = '$funcionario|$cnpj|$dataContrato';
    return base64Url.encode(utf8.encode(raw)).replaceAll('=', '').substring(0, 20);
  }

  static DateTime? _parseYearMonth(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return null;
    final parts = raw.trim().split('-');
    if (parts.length < 2) return null;
    final year = int.tryParse(parts[0]) ?? 0;
    final month = int.tryParse(parts[1]) ?? 1;
    return DateTime(year, month, 1);
  }

  static DateTime? _parseDate(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return null;
    final parts = raw.trim().split('/');
    if (parts.length == 3) {
      final d = int.tryParse(parts[0]) ?? 1;
      final m = int.tryParse(parts[1]) ?? 1;
      final y = int.tryParse(parts[2]) ?? 2000;
      return DateTime(y, m, d);
    }
    return null;
  }

  static double _parseDouble(String? raw) {
    if (raw == null || raw.isEmpty || raw == 'null') return 0.0;
    return double.tryParse(
          raw.trim().replaceAll('.', '').replaceAll(',', '.'),
        ) ??
        0.0;
  }

  TimingLabel get timingLabel {
    final fim = periodoFim ?? DateTime.now();
    if (!dataContrato.isBefore(periodoInicio) && !dataContrato.isAfter(fim)) {
      return const TimingLabel(category: TimingCategory.durante, months: 0);
    }
    if (dataContrato.isBefore(periodoInicio)) {
      return TimingLabel(
        category: TimingCategory.antes,
        months: _monthsBetween(dataContrato, periodoInicio),
      );
    }
    return TimingLabel(
      category: TimingCategory.apos,
      months: _monthsBetween(fim, dataContrato),
    );
  }

  static int _monthsBetween(DateTime from, DateTime to) =>
      (to.year - from.year) * 12 + (to.month - from.month);

  factory ConflittoRecord.fromRow(int index, List<dynamic> row) {
    final funcionario = (row[1] ?? '').toString().trim();
    final cnpj = (row[7] ?? '').toString().trim();
    final dataContratoRaw = (row[15] ?? '').toString().trim();
    return ConflittoRecord(
      index: index,
      tipoCiclo: (row[0] ?? '').toString().trim().toLowerCase(),
      funcionario: funcionario,
      socio: (row[2] ?? '').toString().trim(),
      scoreMatch: _parseDouble((row[3] ?? '').toString()),
      metodoMatch: (row[4] ?? '').toString().trim(),
      orgao: (row[5] ?? '').toString().trim(),
      empresa: (row[6] ?? '').toString().trim(),
      cnpj: cnpj,
      cargo: (row[8] ?? '').toString().trim(),
      funcao: () {
        final f = (row[9] ?? '').toString().trim();
        return (f.isEmpty || f.toLowerCase() == 'null') ? null : f;
      }(),
      vinculo: (row[10] ?? '').toString().trim(),
      lotacao: (row[11] ?? '').toString().trim(),
      remuneracaoTotal: _parseDouble((row[12] ?? '').toString()),
      periodoInicio: _parseYearMonth((row[13] ?? '').toString()) ?? DateTime(2000),
      periodoFim: _parseYearMonth((row[14] ?? '').toString()),
      dataContrato: _parseDate(dataContratoRaw) ?? DateTime(2000),
      valorContrato: _parseDouble((row[16] ?? '').toString()),
      descricao: (row[17] ?? '').toString().trim(),
      qualificacaoSocio: (row[18] ?? '').toString().trim(),
      favoriteKey: _buildKey(funcionario, cnpj, dataContratoRaw),
    );
  }
}
