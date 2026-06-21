import 'package:flutter/material.dart';

class AnalyticsHistogram extends StatelessWidget {
  final List<(String, int)> data;

  const AnalyticsHistogram({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxCount = data.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    final highlightIndex = data.indexOf(
      data.reduce((a, b) => a.$2 >= b.$2 ? a : b),
    );
    final primary = Theme.of(context).colorScheme.primary;
    final secondary = Theme.of(context).colorScheme.secondary;

    return Column(
      children: List.generate(data.length, (i) {
        final entry = data[i];
        final fraction = maxCount > 0 ? entry.$2 / maxCount : 0.0;
        final isHighlight = i == highlightIndex;
        final color = isHighlight ? secondary : primary.withValues(alpha: 0.6);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 110,
                child: Text(
                  entry.$1,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Container(
                    height: 16,
                    width: constraints.maxWidth * fraction,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  '${entry.$2}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: isHighlight ? FontWeight.bold : null,
                      ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}
