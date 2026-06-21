import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/conflito_record.dart';
import '../providers/data_provider.dart';
import '../screens/detail_screen.dart';
import 'timing_label_badge.dart';

final _brl = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
final _dateFormat = DateFormat('dd/MM/yyyy');

class ResultListItem extends StatelessWidget {
  final ConflittoRecord record;

  const ResultListItem({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final isFav = data.isFavorite(record.favoriteKey);
    final inBasket = data.isInBasket(record.index);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => DetailScreen(record: record)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      data.displayName(record.funcionario, 'FUNC'),
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      inBasket ? Icons.download_done : Icons.save_alt,
                      color: inBasket ? Colors.teal : null,
                    ),
                    onPressed: inBasket
                        ? () => data.removeFromBasket(record.index)
                        : () => data.addToBasket(record.index),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                  IconButton(
                    icon: Icon(
                      isFav ? Icons.star : Icons.star_border,
                      color: isFav ? Colors.amber : null,
                    ),
                    onPressed: () => data.toggleFavorite(record.favoriteKey),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${record.orgao} | ${record.empresa}',
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _chip(context, _brl.format(record.valorContrato), Colors.green.shade700),
                  _chip(context, _dateFormat.format(record.dataContrato), Colors.blue.shade700),
                  if (record.tipoCiclo == 'quadrado')
                    _chip(context, '${record.scoreMatch.toStringAsFixed(0)}%', Colors.orange.shade700),
                  TimingLabelBadge(timingLabel: record.timingLabel, compact: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(BuildContext context, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}
