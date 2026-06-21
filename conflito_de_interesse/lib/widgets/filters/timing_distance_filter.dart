import 'package:flutter/material.dart';
import '../../models/filter_state.dart';

class TimingDistanceFilter extends StatelessWidget {
  final Set<TimingDistanceBand> selected;
  final ValueChanged<Set<TimingDistanceBand>> onChanged;

  const TimingDistanceFilter({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  static const _labels = {
    TimingDistanceBand.ate1ano: 'Até 1 ano',
    TimingDistanceBand.ate2anos: '2 anos',
    TimingDistanceBand.ate3anos: '3 anos',
    TimingDistanceBand.mais4anos: '4+ anos',
  };

  void _toggle(TimingDistanceBand band) {
    final next = Set<TimingDistanceBand>.from(selected);
    if (next.contains(band)) {
      next.remove(band);
    } else {
      next.add(band);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: TimingDistanceBand.values.map((band) {
        return CheckboxListTile(
          dense: true,
          title: Text(_labels[band]!),
          value: selected.contains(band),
          onChanged: (_) => _toggle(band),
          controlAffinity: ListTileControlAffinity.leading,
        );
      }).toList(),
    );
  }
}
