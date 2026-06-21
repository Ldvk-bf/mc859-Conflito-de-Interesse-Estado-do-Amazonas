import 'package:flutter/material.dart';
import '../../models/conflito_record.dart';
import '../../models/filter_state.dart';
import 'timing_distance_filter.dart';

class TimingCategoryFilter extends StatelessWidget {
  final Set<TimingCategory> selected;
  final ValueChanged<Set<TimingCategory>> onChanged;
  final Set<TimingDistanceBand> selectedDistances;
  final ValueChanged<Set<TimingDistanceBand>> onDistanceChanged;

  const TimingCategoryFilter({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.selectedDistances,
    required this.onDistanceChanged,
  });

  static const _labels = {
    TimingCategory.durante: 'Durante o vínculo',
    TimingCategory.antes: 'Antes do vínculo',
    TimingCategory.apos: 'Após o vínculo',
  };

  void _toggle(TimingCategory cat) {
    final next = Set<TimingCategory>.from(selected);
    if (next.contains(cat)) {
      next.remove(cat);
    } else {
      next.add(cat);
    }
    onChanged(next);
  }

  bool get _showDistanceFilter =>
      selected.contains(TimingCategory.antes) ||
      selected.contains(TimingCategory.apos);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...TimingCategory.values.map((cat) {
          return CheckboxListTile(
            dense: true,
            title: Text(_labels[cat]!),
            value: selected.contains(cat),
            onChanged: (_) => _toggle(cat),
            controlAffinity: ListTileControlAffinity.leading,
          );
        }),
        if (_showDistanceFilter) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4, bottom: 2),
            child: Text(
              'Distância em anos:',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          TimingDistanceFilter(
            selected: selectedDistances,
            onChanged: onDistanceChanged,
          ),
        ],
      ],
    );
  }
}
