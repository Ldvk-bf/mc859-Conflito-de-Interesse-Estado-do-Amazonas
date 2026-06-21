import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conflito_record.dart';
import '../models/favorite_company_summary.dart';
import '../providers/data_provider.dart';
import '../widgets/anonymize_toggle_button.dart';
import '../widgets/socio_list_item.dart';

class CompanyDetailScreen extends StatelessWidget {
  final FavoriteCompanySummary summary;

  const CompanyDetailScreen({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          summary.empresa,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [AnonymizeToggleButton()],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.amber.shade50,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Colors.amber.shade800),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Esta lista inclui apenas servidores públicos cruzados com o dataset — pode haver outros sócios não mapeados.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Consumer<DataProvider>(
              builder: (_, data, _) {
                final records =
                    data.recordsForCompany(summary.empresaKey);
                final byPerson = <String, ConflittoRecord>{};
                for (final r in records) {
                  if (!byPerson.containsKey(r.funcionario) ||
                      r.scoreMatch > byPerson[r.funcionario]!.scoreMatch) {
                    byPerson[r.funcionario] = r;
                  }
                }
                final socios = byPerson.values.toList()
                  ..sort((a, b) => a.funcionario.compareTo(b.funcionario));

                if (socios.isEmpty) {
                  return const Center(
                      child: Text('Nenhum servidor encontrado.'));
                }
                return ListView.builder(
                  itemCount: socios.length,
                  itemBuilder: (_, i) => SocioListItem(record: socios[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
