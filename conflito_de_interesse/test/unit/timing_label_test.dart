import 'package:flutter_test/flutter_test.dart';
import 'package:conflito_de_interesse/models/conflito_record.dart';

ConflittoRecord _rec({
  required DateTime periodoInicio,
  DateTime? periodoFim,
  required DateTime dataContrato,
}) {
  return ConflittoRecord(
    index: 0,
    tipoCiclo: 'triangulo',
    funcionario: 'Test',
    socio: 'Test',
    scoreMatch: 100,
    metodoMatch: 'exact',
    orgao: 'SEAD',
    empresa: 'Empresa',
    cnpj: '12345678000190',
    cargo: 'ANALISTA',
    vinculo: 'ESTATUTARIO',
    lotacao: 'LOC',
    remuneracaoTotal: 5000,
    periodoInicio: periodoInicio,
    periodoFim: periodoFim,
    dataContrato: dataContrato,
    valorContrato: 50000,
    descricao: 'Desc',
    qualificacaoSocio: 'Sócio',
    favoriteKey: 'key_0',
  );
}

void main() {
  group('timingLabel getter — category', () {
    test('dataContrato within period → durante', () {
      final r = _rec(
        periodoInicio: DateTime(2018, 1, 1),
        periodoFim: DateTime(2023, 1, 1),
        dataContrato: DateTime(2020, 6, 1),
      );
      expect(r.timingLabel.category, TimingCategory.durante);
    });

    test('dataContrato on periodoInicio boundary → durante', () {
      final r = _rec(
        periodoInicio: DateTime(2018, 1, 1),
        periodoFim: DateTime(2023, 1, 1),
        dataContrato: DateTime(2018, 1, 1),
      );
      expect(r.timingLabel.category, TimingCategory.durante);
    });

    test('dataContrato on periodoFim boundary → durante', () {
      final r = _rec(
        periodoInicio: DateTime(2018, 1, 1),
        periodoFim: DateTime(2023, 1, 1),
        dataContrato: DateTime(2023, 1, 1),
      );
      expect(r.timingLabel.category, TimingCategory.durante);
    });

    test('dataContrato before periodoInicio → antes', () {
      final r = _rec(
        periodoInicio: DateTime(2020, 1, 1),
        dataContrato: DateTime(2018, 6, 1),
      );
      expect(r.timingLabel.category, TimingCategory.antes);
    });

    test('dataContrato after periodoFim → apos', () {
      final r = _rec(
        periodoInicio: DateTime(2015, 1, 1),
        periodoFim: DateTime(2018, 1, 1),
        dataContrato: DateTime(2019, 3, 1),
      );
      expect(r.timingLabel.category, TimingCategory.apos);
    });

    test('null periodoFim treats period as open-ended (uses now)', () {
      final r = _rec(
        periodoInicio: DateTime(2018, 1, 1),
        periodoFim: null,
        dataContrato: DateTime(2022, 1, 1),
      );
      // 2022 is between 2018 and "now" (2026), so durante
      expect(r.timingLabel.category, TimingCategory.durante);
    });
  });

  group('timingLabel getter — months calculation', () {
    test('antes: 18 months before periodoInicio', () {
      final r = _rec(
        periodoInicio: DateTime(2020, 7, 1),
        dataContrato: DateTime(2019, 1, 1),
      );
      expect(r.timingLabel.category, TimingCategory.antes);
      expect(r.timingLabel.months, 18);
    });

    test('apos: 14 months after periodoFim', () {
      final r = _rec(
        periodoInicio: DateTime(2015, 1, 1),
        periodoFim: DateTime(2018, 1, 1),
        dataContrato: DateTime(2019, 3, 1),
      );
      expect(r.timingLabel.category, TimingCategory.apos);
      expect(r.timingLabel.months, 14);
    });

    test('durante: months is 0', () {
      final r = _rec(
        periodoInicio: DateTime(2018, 1, 1),
        periodoFim: DateTime(2023, 1, 1),
        dataContrato: DateTime(2020, 1, 1),
      );
      expect(r.timingLabel.months, 0);
    });
  });

  group('TimingLabel.displayText', () {
    test('durante → "Durante o vínculo"', () {
      const label = TimingLabel(category: TimingCategory.durante, months: 0);
      expect(label.displayText, 'Durante o vínculo');
    });

    test('antes 6 months → "6 meses antes do vínculo"', () {
      const label = TimingLabel(category: TimingCategory.antes, months: 6);
      expect(label.displayText, '6 meses antes do vínculo');
    });

    test('antes 1 month → singular "mês"', () {
      const label = TimingLabel(category: TimingCategory.antes, months: 1);
      expect(label.displayText, '1 mês antes do vínculo');
    });

    test('apos 12 months → "1 ano após o vínculo"', () {
      const label = TimingLabel(category: TimingCategory.apos, months: 12);
      expect(label.displayText, '1 ano após o vínculo');
    });

    test('antes 24 months → "2 anos antes do vínculo"', () {
      const label = TimingLabel(category: TimingCategory.antes, months: 24);
      expect(label.displayText, '2 anos antes do vínculo');
    });

    test('antes 14 months → "1 ano e 2 meses antes do vínculo"', () {
      const label = TimingLabel(category: TimingCategory.antes, months: 14);
      expect(label.displayText, '1 ano e 2 meses antes do vínculo');
    });
  });

  group('TimingLabel.compactText', () {
    test('durante → "Durante"', () {
      const label = TimingLabel(category: TimingCategory.durante, months: 0);
      expect(label.compactText, 'Durante');
    });

    test('antes 6 months → "6m antes"', () {
      const label = TimingLabel(category: TimingCategory.antes, months: 6);
      expect(label.compactText, '6m antes');
    });

    test('apos 12 months → "1a após"', () {
      const label = TimingLabel(category: TimingCategory.apos, months: 12);
      expect(label.compactText, '1a após');
    });

    test('antes 14 months → "1a 2m antes"', () {
      const label = TimingLabel(category: TimingCategory.antes, months: 14);
      expect(label.compactText, '1a 2m antes');
    });
  });
}
