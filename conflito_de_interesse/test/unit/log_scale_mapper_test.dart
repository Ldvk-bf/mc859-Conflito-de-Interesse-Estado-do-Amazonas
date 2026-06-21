import 'package:flutter_test/flutter_test.dart';
import 'package:conflito_de_interesse/utils/log_scale_mapper.dart';

void main() {
  group('LogScaleMapper', () {
    final mapper = LogScaleMapper(minValue: 0, maxValue: 196489860);

    test('toValue(0.0) == 0 (minValue)', () {
      expect(mapper.toValue(0.0), equals(0.0));
    });

    test('toValue(1.0) == maxValue', () {
      expect(mapper.toValue(1.0), closeTo(196489860, 1.0));
    });

    test('round-trip: toPosition(toValue(0.5)) ≈ 0.5', () {
      expect(mapper.toPosition(mapper.toValue(0.5)), closeTo(0.5, 0.001));
    });

    test('toValue(0.25) < 1_000_000 for max=196M (much less than linear R\$49M)', () {
      expect(mapper.toValue(0.25), lessThan(1000000));
    });

    test('degenerate: minValue == maxValue returns minValue for any position', () {
      final flat = LogScaleMapper(minValue: 100, maxValue: 100);
      expect(flat.toValue(0.0), equals(100.0));
      expect(flat.toValue(0.5), equals(100.0));
      expect(flat.toValue(1.0), equals(100.0));
    });

    test('toPosition clamps value below minValue to 0.0', () {
      expect(mapper.toPosition(-1), equals(0.0));
    });

    test('toPosition clamps value above maxValue to 1.0', () {
      expect(mapper.toPosition(200000000), equals(1.0));
    });

    test('effectiveMin is max(1.0, minValue)', () {
      final m = LogScaleMapper(minValue: 0, maxValue: 1000);
      expect(m.effectiveMin, equals(1.0));
      final m2 = LogScaleMapper(minValue: 500, maxValue: 1000);
      expect(m2.effectiveMin, equals(500.0));
    });
  });
}
