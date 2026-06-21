import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/filter_provider.dart';

class CycleTypeFilter extends StatelessWidget {
  const CycleTypeFilter({super.key});

  @override
  Widget build(BuildContext context) {
    final filter = context.watch<FilterProvider>();
    final state = filter.state;

    return Wrap(
      spacing: 8,
      children: [
        FilterChip(
          avatar: const Icon(Icons.change_history, size: 16),
          label: const Text('Triângulo (exato)'),
          selected: state.incluiTriangulo,
          onSelected: (v) => filter.updateCycleAndScore(triangulo: v),
        ),
        FilterChip(
          avatar: const Icon(Icons.crop_square, size: 16),
          label: const Text('Quadrado (similaridade)'),
          selected: state.incluiQuadrado,
          onSelected: (v) => filter.updateCycleAndScore(quadrado: v),
        ),
      ],
    );
  }
}
