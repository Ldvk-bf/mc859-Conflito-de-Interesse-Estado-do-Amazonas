import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conflito_record.dart';
import '../models/favorite_orgao_summary.dart';
import '../providers/data_provider.dart';
import '../widgets/anonymize_toggle_button.dart';
import '../widgets/socio_list_item.dart';

class OrgaoDetailScreen extends StatelessWidget {
  final FavoriteOrgaoSummary summary;

  const OrgaoDetailScreen({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          summary.orgao,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: const [AnonymizeToggleButton()],
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '${summary.nFavoritados} favorito(s) entre ${summary.nRegistros} servidor(es) deste órgão no dataset.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Consumer<DataProvider>(
              builder: (_, data, _) {
                final records = data.recordsForOrgao(summary.orgao);
                final byPerson = <String, ConflittoRecord>{};
                for (final r in records) {
                  if (!byPerson.containsKey(r.funcionario) ||
                      r.scoreMatch > byPerson[r.funcionario]!.scoreMatch) {
                    byPerson[r.funcionario] = r;
                  }
                }
                final servidores = byPerson.values.toList()
                  ..sort((a, b) => a.funcionario.compareTo(b.funcionario));

                if (servidores.isEmpty) {
                  return const Center(
                      child: Text('Nenhum servidor encontrado.'));
                }
                return ListView.builder(
                  itemCount: servidores.length,
                  itemBuilder: (_, i) => SocioListItem(record: servidores[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
