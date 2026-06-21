import 'package:flutter/material.dart';
import '../models/conflito_record.dart';

class TimingLabelBadge extends StatelessWidget {
  final TimingLabel timingLabel;
  final bool compact;

  const TimingLabelBadge({
    super.key,
    required this.timingLabel,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final (color, textColor) = switch (timingLabel.category) {
      TimingCategory.durante => (
          const Color(0xFFD4EDDA),
          const Color(0xFF155724)
        ),
      TimingCategory.antes => (
          const Color(0xFFFFF3CD),
          const Color(0xFF856404)
        ),
      TimingCategory.apos => (
          const Color(0xFFF8D7DA),
          const Color(0xFF721C24)
        ),
    };

    final text = compact ? timingLabel.compactText : timingLabel.displayText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: compact ? 10 : 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
