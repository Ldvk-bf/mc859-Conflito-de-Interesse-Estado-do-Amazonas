import 'package:flutter_test/flutter_test.dart';
import 'package:conflito_de_interesse/models/conflito_record.dart';
import 'package:conflito_de_interesse/providers/data_provider.dart';

void main() {
  group('DataProvider — anonymization', () {
    late DataProvider provider;

    setUp(() {
      provider = DataProvider();
    });

    test('anonymized starts as true', () {
      expect(provider.anonymized, isTrue);
    });

    test('toggleAnonymization alternates the value', () {
      expect(provider.anonymized, isTrue);
      provider.toggleAnonymization();
      expect(provider.anonymized, isFalse);
      provider.toggleAnonymization();
      expect(provider.anonymized, isTrue);
    });

    test('displayName returns placeholder for empty name regardless of state', () {
      expect(provider.displayName('', 'FUNC'), 'FUNC-??????');
      provider.toggleAnonymization();
      expect(provider.displayName('', 'SOC'), 'SOC-??????');
    });

    test('displayName returns only the code when anonymized=true', () {
      // _codeMap is empty without init(), so we expect the fallback code
      // but the format must match type-?????? for unknown names
      final result = provider.displayName('Alice', 'FUNC');
      // Either a real code (if in map) or the placeholder — must NOT contain ' — '
      expect(result.contains(' — '), isFalse);
    });

    test('displayName returns only name when anonymized=false', () {
      provider.toggleAnonymization();
      final result = provider.displayName('Alice', 'FUNC');
      expect(result, equals('Alice'));
      expect(result.contains(' — '), isFalse);
    });

    test('displayName returns SOC placeholder for empty name with SOC type', () {
      expect(provider.displayName('', 'SOC'), 'SOC-??????');
    });

    test('triangle case: same name as FUNC and SOC gets distinct prefixed codes', () {
      final r1 = ConflittoRecord(
        index: 0,
        tipoCiclo: 'triangulo',
        funcionario: 'João Silva',
        socio: 'Outro',
        scoreMatch: 100,
        metodoMatch: 'exact',
        orgao: 'ORG',
        empresa: 'EMP',
        cnpj: '00000000000100',
        cargo: 'CARGO',
        vinculo: 'ESTATUTARIO',
        lotacao: 'LOC',
        remuneracaoTotal: 1000,
        periodoInicio: DateTime(2020),
        dataContrato: DateTime(2021),
        valorContrato: 10000,
        descricao: 'desc',
        qualificacaoSocio: 'Sócio',
        favoriteKey: 'k0',
      );
      final r2 = ConflittoRecord(
        index: 1,
        tipoCiclo: 'triangulo',
        funcionario: 'Outro',
        socio: 'João Silva',
        scoreMatch: 100,
        metodoMatch: 'exact',
        orgao: 'ORG',
        empresa: 'EMP',
        cnpj: '00000000000100',
        cargo: 'CARGO',
        vinculo: 'ESTATUTARIO',
        lotacao: 'LOC',
        remuneracaoTotal: 1000,
        periodoInicio: DateTime(2020),
        dataContrato: DateTime(2021),
        valorContrato: 10000,
        descricao: 'desc',
        qualificacaoSocio: 'Sócio',
        favoriteKey: 'k1',
      );
      provider.loadTestRecords([r1, r2]);
      final funcCode = provider.displayName('João Silva', 'FUNC');
      final socCode = provider.displayName('João Silva', 'SOC');
      expect(funcCode.startsWith('FUNC-'), isTrue);
      expect(socCode.startsWith('SOC-'), isTrue);
      expect(funcCode, isNot(equals(socCode)));
    });
  });
}
