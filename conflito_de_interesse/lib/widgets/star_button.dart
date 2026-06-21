import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';

class StarButton extends StatelessWidget {
  final String favoriteKey;
  final bool compact;

  const StarButton({super.key, required this.favoriteKey, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final isFav = data.isFavorite(favoriteKey);

    return Semantics(
      label: isFav ? 'Remover dos favoritos' : 'Adicionar aos favoritos',
      button: true,
      child: IconButton(
        icon: Icon(
          isFav ? Icons.star : Icons.star_border,
          color: isFav ? Colors.amber : null,
        ),
        visualDensity:
            compact ? VisualDensity.compact : VisualDensity.standard,
        padding: compact ? EdgeInsets.zero : null,
        onPressed: () => data.toggleFavorite(favoriteKey),
      ),
    );
  }
}
