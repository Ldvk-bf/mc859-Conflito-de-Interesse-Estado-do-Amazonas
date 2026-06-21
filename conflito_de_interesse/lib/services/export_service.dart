import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/conflito_record.dart';

class ExportService {
  Future<void> export(
    List<ConflittoRecord> records,
    String filename, {
    String separator = ',',
    Rect? sharePositionOrigin,
    String Function(String, String)? nameDisplay,
  }) async {
    final csv = _buildCsv(records, separator, nameDisplay: nameDisplay);
    final dir = Platform.isMacOS
        ? await getApplicationSupportDirectory()
        : await getTemporaryDirectory();
    final file = File('${dir.path}/$filename.csv');
    await file.writeAsString(csv);
    // On macOS, NSSharingServicePicker silently fails with a zero rect.
    // Guarantee a non-zero origin so the picker can position itself.
    final origin = (sharePositionOrigin == null || sharePositionOrigin.isEmpty) &&
            Platform.isMacOS
        ? const Rect.fromLTWH(0, 0, 1, 1)
        : sharePositionOrigin;
    debugPrint('[SHARE_DEBUG] file: ${file.path} (${await file.length()} bytes) | origin: $origin');
    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: filename,
      sharePositionOrigin: origin,
    );
  }

  Future<void> exportBasket(
    List<ConflittoRecord> records, {
    Rect? sharePositionOrigin,
    String Function(String, String)? nameDisplay,
  }) async {
    final now = DateTime.now();
    final name =
        'cesta_exportacao_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    await export(records, name, separator: ';', sharePositionOrigin: sharePositionOrigin, nameDisplay: nameDisplay);
  }

  String _buildCsv(List<ConflittoRecord> records, String separator, {String Function(String, String)? nameDisplay}) {
    const header =
        'tipo_ciclo;funcionario;socio;score_match;metodo_match;orgao;empresa;cnpj;'
        'cargo;funcao;vinculo;lotacao;remuneracao_total;periodo_inicio;periodo_fim;'
        'data_contrato;valor_contrato;descricao;qualificacao_socio';

    final rows = records.map((r) => [
          _q(r.tipoCiclo),
          _q(nameDisplay != null ? nameDisplay(r.funcionario, 'FUNC') : r.funcionario),
          _q(nameDisplay != null ? nameDisplay(r.socio, 'SOC') : r.socio),
          r.scoreMatch,
          _q(r.metodoMatch),
          _q(r.orgao),
          _q(r.empresa),
          _q(r.cnpj),
          _q(r.cargo),
          _q(r.funcao ?? ''),
          _q(r.vinculo),
          _q(r.lotacao),
          r.remuneracaoTotal,
          '${r.periodoInicio.year}-${r.periodoInicio.month.toString().padLeft(2, '0')}',
          r.periodoFim != null
              ? '${r.periodoFim!.year}-${r.periodoFim!.month.toString().padLeft(2, '0')}'
              : '',
          '${r.dataContrato.day.toString().padLeft(2, '0')}/${r.dataContrato.month.toString().padLeft(2, '0')}/${r.dataContrato.year}',
          r.valorContrato,
          _q(r.descricao),
          _q(r.qualificacaoSocio),
        ].join(separator));

    return '${header.replaceAll(';', separator)}\n${rows.join('\n')}';
  }

  String _q(String s) => '"${s.replaceAll('"', '""')}"';
}
