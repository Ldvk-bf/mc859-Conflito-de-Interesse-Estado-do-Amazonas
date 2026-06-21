import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/filter_provider.dart';

class ScoreRangeFilter extends StatelessWidget {
  const ScoreRangeFilter({super.key});

  @override
  Widget build(BuildContext context) {
    final filter = context.watch<FilterProvider>();
    final state = filter.state;
    final enabled = state.incluiQuadrado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Score: ${state.scoreMin.toStringAsFixed(0)}–${state.scoreMax.toStringAsFixed(0)}',
          style: TextStyle(color: enabled ? null : Colors.grey),
        ),
        RangeSlider(
          values: RangeValues(state.scoreMin, state.scoreMax),
          min: 92,
          max: 100,
          divisions: 8,
          labels: RangeLabels(
            state.scoreMin.toStringAsFixed(0),
            state.scoreMax.toStringAsFixed(0),
          ),
          onChanged: enabled
              ? (v) => filter.updateCycleAndScore(
                    scoreMin: v.start,
                    scoreMax: v.end,
                  )
              : null,
        ),
        if (!enabled)
          const Text(
            'Ative "Quadrado" para filtrar por score.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
      ],
    );
  }
}
