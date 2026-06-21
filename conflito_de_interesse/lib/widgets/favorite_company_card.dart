import 'package:flutter/material.dart';
import '../models/favorite_company_summary.dart';

class FavoriteCompanyCard extends StatelessWidget {
  final FavoriteCompanySummary summary;
  final VoidCallback onTap;

  const FavoriteCompanyCard({
    super.key,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.empresa,
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (summary.cnpj.isNotEmpty)
                    Text(
                      summary.cnpj,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey,
                          ),
                    ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (summary.nTriangulos > 0)
                    _chip(context, '▲ ${summary.nTriangulos}',
                        Colors.blue.shade700),
                  if (summary.nQuadrados > 0)
                    _chip(context, '■ ${summary.nQuadrados}',
                        Colors.orange.shade700),
                  _chip(
                    context,
                    '${summary.sociosFavoritados.length} favorito(s)',
                    Colors.amber.shade700,
                  ),
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
