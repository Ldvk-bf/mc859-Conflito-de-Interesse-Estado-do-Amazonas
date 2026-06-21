import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/conflito_record.dart';
import '../providers/data_provider.dart';
import '../widgets/anonymize_toggle_button.dart';
import '../widgets/timing_label_badge.dart';

final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _dateFmt = DateFormat('dd/MM/yyyy');

class DetailScreen extends StatelessWidget {
  final ConflittoRecord record;

  const DetailScreen({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final isFav = data.isFavorite(record.favoriteKey);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhe'),
        actions: [
          const AnonymizeToggleButton(),
          IconButton(
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? Colors.amber : null,
            ),
            onPressed: () => data.toggleFavorite(record.favoriteKey),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section(context, 'Servidor'),
          _row('Nome', data.displayName(record.funcionario, 'FUNC')),
          _row('Órgão', record.orgao),
          _row('Cargo', record.cargo),
          if (record.funcao != null) _row('Função', record.funcao!),
          _row('Vínculo', record.vinculo),
          _row('Lotação', record.lotacao),
          _row('Remuneração', _brl.format(record.remuneracaoTotal)),
          _row('Período', _formatPeriodo()),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 170,
                  child: Text(
                    'Temporalidade',
                    style: TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                ),
                TimingLabelBadge(timingLabel: record.timingLabel, compact: false),
              ],
            ),
          ),
          const Divider(height: 24),
          _section(context, 'Empresa'),
          _row('Razão social', record.empresa),
          _row('CNPJ', record.cnpj),
          _row('Qualificação do sócio', record.qualificacaoSocio),
          _row('Sócio encontrado', data.displayName(record.socio, 'SOC')),
          const Divider(height: 24),
          _section(context, 'Contrato'),
          _row('Data', _dateFmt.format(record.dataContrato)),
          _row('Valor', _brl.format(record.valorContrato)),
          _row('Descrição', record.descricao),
          const Divider(height: 24),
          _section(context, 'Análise'),
          _row(
            'Tipo de ciclo',
            record.tipoCiclo == 'triangulo'
                ? 'Triângulo (correspondência exata)'
                : 'Quadrado (similaridade de nomes)',
          ),
          if (record.tipoCiclo == 'quadrado')
            _row('Score de similaridade', '${record.scoreMatch.toStringAsFixed(1)}%'),
          _row('Método', record.metodoMatch),
        ],
      ),
    );
  }

  String _formatPeriodo() {
    final start = _dateFmt.format(record.periodoInicio);
    if (record.periodoFim == null) return '$start – atual';
    return '$start – ${_dateFmt.format(record.periodoFim!)}';
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 170,
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
              ),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
}
