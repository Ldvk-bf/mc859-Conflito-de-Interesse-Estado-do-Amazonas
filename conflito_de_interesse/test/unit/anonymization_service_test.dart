import 'package:flutter_test/flutter_test.dart';
import 'package:conflito_de_interesse/services/anonymization_service.dart';

void main() {
  group('AnonymizationService', () {
    test('normalize trims and uppercases', () {
      expect(AnonymizationService.normalize('  joão silva  '), 'JOÃO SILVA');
      expect(AnonymizationService.normalize('Ana'), 'ANA');
    });

    test('normalize handles empty string without exception', () {
      expect(() => AnonymizationService.normalize(''), returnsNormally);
      expect(AnonymizationService.normalize(''), '');
    });

    test('hash is deterministic', () {
      final h1 = AnonymizationService.hash('JOÃO SILVA');
      final h2 = AnonymizationService.hash('JOÃO SILVA');
      expect(h1, h2);
    });

    test('hash is case-insensitive via normalize', () {
      final h1 = AnonymizationService.hash(AnonymizationService.normalize('joão silva'));
      final h2 = AnonymizationService.hash(AnonymizationService.normalize('JOÃO SILVA'));
      expect(h1, h2);
    });

    test('hash of empty string does not throw', () {
      expect(() => AnonymizationService.hash(''), returnsNormally);
    });

    test('hexCode always returns 6 chars uppercase', () {
      for (final name in ['A', 'JOÃO', 'MARIA DE FATIMA', '']) {
        final h = AnonymizationService.hash(AnonymizationService.normalize(name));
        final code = AnonymizationService.hexCode(h);
        expect(code.length, 6, reason: 'Expected 6 chars for "$name", got "$code"');
        expect(code, code.toUpperCase(), reason: 'Expected uppercase for "$name"');
      }
    });

    test('two distinct names produce distinct hashes (no trivial collision)', () {
      final h1 = AnonymizationService.hash(AnonymizationService.normalize('ALICE'));
      final h2 = AnonymizationService.hash(AnonymizationService.normalize('BOB'));
      expect(h1, isNot(h2));
    });
  });
}
