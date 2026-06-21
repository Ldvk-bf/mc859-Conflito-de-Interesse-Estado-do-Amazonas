import 'package:flutter/material.dart';

class AnalyticsBarChart extends StatelessWidget {
  final List<(String, int)> data;
  final Color? barColor;

  const AnalyticsBarChart({super.key, required this.data, this.barColor});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxCount = data.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    final color = barColor ?? Theme.of(context).colorScheme.primary;

    return Column(
      children: data.map((entry) {
        final fraction = maxCount > 0 ? entry.$2 / maxCount : 0.0;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  entry.$1,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) => Stack(
                    children: [
                      Container(
                        height: 16,
                        width: constraints.maxWidth * fraction,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text(
                  '${entry.$2}',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
