import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/conflito_record.dart';
import '../providers/data_provider.dart';
import '../screens/detail_screen.dart';

class SocioListItem extends StatelessWidget {
  final ConflittoRecord record;

  const SocioListItem({super.key, required this.record});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DataProvider>();
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.person)),
      title: Text(provider.displayName(record.funcionario, 'FUNC')),
      subtitle: Text(record.orgao),
      trailing: Consumer<DataProvider>(
        builder: (_, data, _) {
          final isFav = data.isFavorite(record.favoriteKey);
          return IconButton(
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? Colors.amber : null,
            ),
            onPressed: () => data.toggleFavorite(record.favoriteKey),
          );
        },
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DetailScreen(record: record)),
      ),
    );
  }
}
