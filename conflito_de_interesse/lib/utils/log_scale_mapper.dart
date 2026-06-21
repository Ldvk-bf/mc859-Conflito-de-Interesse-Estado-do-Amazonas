import 'dart:math';

class LogScaleMapper {
  final double minValue;
  final double maxValue;

  const LogScaleMapper({required this.minValue, required this.maxValue});

  double get effectiveMin => max(1.0, minValue);

  double toValue(double position) {
    if (position == 0.0) return minValue;
    if (position == 1.0) return maxValue;
    if (minValue == maxValue) return minValue;
    final logMin = log(effectiveMin) / ln10;
    final logMax = log(maxValue) / ln10;
    return pow(10, logMin + position * (logMax - logMin)).toDouble();
  }

  double toPosition(double value) {
    if (value <= minValue) return 0.0;
    if (value >= maxValue) return 1.0;
    if (minValue == maxValue) return 0.0;
    final logMin = log(effectiveMin) / ln10;
    final logMax = log(maxValue) / ln10;
    final logVal = log(value) / ln10;
    return ((logVal - logMin) / (logMax - logMin)).clamp(0.0, 1.0);
  }
}
