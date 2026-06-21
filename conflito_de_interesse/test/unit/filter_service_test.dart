import 'package:flutter_test/flutter_test.dart';
import 'package:conflito_de_interesse/models/conflito_record.dart';
import 'package:conflito_de_interesse/models/filter_state.dart';
import 'package:conflito_de_interesse/services/filter_service.dart';

ConflittoRecord _rec({
  String tipoCiclo = 'triangulo',
  double scoreMatch = 100.0,
  String orgao = 'SEAD',
  String empresa = 'Empresa Teste',
  String cargo = 'ANALISTA',
  String? funcao,
  String vinculo = 'ESTATUTARIO',
  String qualificacaoSocio = 'Sócio-Administrador',
  double remuneracaoTotal = 5000.0,
  double valorContrato = 50000.0,
  DateTime? periodoInicio,
  DateTime? periodoFim,
  DateTime? dataContrato,
  String funcionario = 'Joao Silva',
  String socio = 'Joao Silva',
  int index = 0,
}) {
  return ConflittoRecord(
    index: index,
    tipoCiclo: tipoCiclo,
    funcionario: funcionario,
    socio: socio,
    scoreMatch: scoreMatch,
    metodoMatch: 'exact',
    orgao: orgao,
    empresa: empresa,
    cnpj: '12345678000190',
    cargo: cargo,
    funcao: funcao,
    vinculo: vinculo,
    lotacao: 'Lotacao Teste',
    remuneracaoTotal: remuneracaoTotal,
    periodoInicio: periodoInicio ?? DateTime(2018, 1, 1),
    periodoFim: periodoFim,
    dataContrato: dataContrato ?? DateTime(2020, 1, 1),
    valorContrato: valorContrato,
    descricao: 'Contrato de teste',
    qualificacaoSocio: qualificacaoSocio,
    favoriteKey: 'key_$index',
  );
}

// Record whose dataContrato is before periodoInicio → TimingCategory.antes
ConflittoRecord _recAntes({int index = 0, String funcionario = 'Joao Silva'}) =>
    _rec(
      periodoInicio: DateTime(2020, 1, 1),
      dataContrato: DateTime(2018, 1, 1),
      funcionario: funcionario,
      index: index,
    );

// Record whose dataContrato is after periodoFim → TimingCategory.apos
ConflittoRecord _recApos({int index = 0, String funcionario = 'Joao Silva'}) =>
    _rec(
      periodoInicio: DateTime(2015, 1, 1),
      periodoFim: DateTime(2018, 1, 1),
      dataContrato: DateTime(2019, 1, 1),
      funcionario: funcionario,
      index: index,
    );

// Record whose dataContrato is within periodoInicio..periodoFim → TimingCategory.durante
ConflittoRecord _recDurante({int index = 0, String funcionario = 'Joao Silva'}) =>
    _rec(
      periodoInicio: DateTime(2018, 1, 1),
      periodoFim: DateTime(2023, 1, 1),
      dataContrato: DateTime(2020, 1, 1),
      funcionario: funcionario,
      index: index,
    );

void main() {
  final svc = FilterService();

  group('FilterService — timing category filter', () {
    final durante = _recDurante(index: 0);
    final antes = _recAntes(index: 1);
    final apos = _recApos(index: 2);
    final all = [durante, antes, apos];

    test('all 3 categories selected → all records pass', () {
      final state = FilterState.defaults();
      expect(svc.apply(all, state), hasLength(3));
    });

    test('only durante → excludes antes and apos', () {
      final state = FilterState.defaults().copyWith(
        timingCategoriesSelecionadas: {TimingCategory.durante},
      );
      final result = svc.apply(all, state);
      expect(result, [durante]);
    });

    test('only antes → excludes durante and apos', () {
      final state = FilterState.defaults().copyWith(
        timingCategoriesSelecionadas: {TimingCategory.antes},
      );
      final result = svc.apply(all, state);
      expect(result, [antes]);
    });

    test('antes + apos → excludes durante (porta giratória subset)', () {
      final state = FilterState.defaults().copyWith(
        timingCategoriesSelecionadas: {TimingCategory.antes, TimingCategory.apos},
      );
      final result = svc.apply(all, state);
      expect(result.length, 2);
      expect(result.contains(durante), isFalse);
    });

    test('empty set → 0 results', () {
      final state = FilterState.defaults().copyWith(
        timingCategoriesSelecionadas: <TimingCategory>{},
      );
      expect(svc.apply(all, state), isEmpty);
    });
  });

  group('FilterService — sort by funcionario', () {
    final rA = _recDurante(funcionario: 'Ana Lima', index: 0);
    final rB = _recDurante(funcionario: 'Carlos Mendes', index: 1);
    final rC = _recDurante(funcionario: 'Bruno Souza', index: 2);

    test('sort funcionario asc → A→Z', () {
      final state = FilterState.defaults().copyWith(
        sortColumn: SortColumn.funcionario,
        sortDirection: SortDirection.asc,
      );
      final result = svc.apply([rB, rC, rA], state);
      expect(result.map((r) => r.funcionario).toList(),
          ['Ana Lima', 'Bruno Souza', 'Carlos Mendes']);
    });

    test('sort funcionario desc → Z→A', () {
      final state = FilterState.defaults().copyWith(
        sortColumn: SortColumn.funcionario,
        sortDirection: SortDirection.desc,
      );
      final result = svc.apply([rA, rB, rC], state);
      expect(result.map((r) => r.funcionario).toList(),
          ['Carlos Mendes', 'Bruno Souza', 'Ana Lima']);
    });

    test('tiebreak: same name → most recent dataContrato first', () {
      final earlier = _recDurante(
        funcionario: 'Joao Silva',
        index: 0,
      );
      // build a record with same name but later dataContrato
      final later = ConflittoRecord(
        index: 1,
        tipoCiclo: 'triangulo',
        funcionario: 'Joao Silva',
        socio: 'Joao Silva',
        scoreMatch: 100.0,
        metodoMatch: 'exact',
        orgao: 'SEAD',
        empresa: 'Empresa',
        cnpj: '12345678000190',
        cargo: 'ANALISTA',
        vinculo: 'ESTATUTARIO',
        lotacao: 'LOC',
        remuneracaoTotal: 5000.0,
        periodoInicio: DateTime(2018, 1, 1),
        periodoFim: DateTime(2023, 1, 1),
        dataContrato: DateTime(2021, 6, 1),
        valorContrato: 50000.0,
        descricao: 'Contrato',
        qualificacaoSocio: 'Sócio',
        favoriteKey: 'key_1',
      );
      final state = FilterState.defaults().copyWith(
        sortColumn: SortColumn.funcionario,
        sortDirection: SortDirection.asc,
      );
      final result = svc.apply([earlier, later], state);
      expect(result.first.dataContrato, later.dataContrato);
    });
  });

  group('FilterService — favorites sort independence', () {
    final r1 = _recDurante(funcionario: 'Ana Lima', index: 0);
    final r2 = _recDurante(funcionario: 'Carlos Mendes', index: 1);

    test('changing favoriteSortColumn does not affect sortColumn', () {
      final state = FilterState.defaults().copyWith(
        favoriteSortColumn: SortColumn.funcionario,
        favoriteSortDirection: SortDirection.asc,
      );
      expect(state.sortColumn, SortColumn.scoreMatch);
      expect(state.sortDirection, SortDirection.desc);
    });

    test('sortFavorites uses favoriteSortColumn independently', () {
      final state = FilterState.defaults().copyWith(
        sortColumn: SortColumn.scoreMatch,
        favoriteSortColumn: SortColumn.funcionario,
        favoriteSortDirection: SortDirection.asc,
      );
      final sorted = svc.sortFavorites([r2, r1], state);
      expect(sorted.map((r) => r.funcionario).toList(),
          ['Ana Lima', 'Carlos Mendes']);
    });

    test('apply() uses sortColumn, not favoriteSortColumn', () {
      final state = FilterState.defaults().copyWith(
        sortColumn: SortColumn.scoreMatch,
        sortDirection: SortDirection.desc,
        favoriteSortColumn: SortColumn.funcionario,
      );
      // Both have same score (100), order should be stable; what matters is
      // that apply() doesn't throw and uses the main sortColumn.
      final result = svc.apply([r1, r2], state);
      expect(result.length, 2);
    });
  });

  group('FilterService — categorical', () {
    final rec = _recDurante(index: 0);

    test('null orgaosSelecionados (no filter) passes all', () {
      final state = FilterState.defaults(); // null = no filter
      expect(svc.apply([rec], state), hasLength(1));
    });

    test('empty set orgaosSelecionados passes nothing', () {
      final state = FilterState.defaults()
          .copyWith(orgaosSelecionados: () => <String>{});
      expect(svc.apply([rec], state), isEmpty);
    });

    test('matching orgao passes', () {
      final state = FilterState.defaults()
          .copyWith(orgaosSelecionados: () => {'SEAD'});
      expect(svc.apply([rec], state), hasLength(1));
    });

    test('non-matching orgao excluded', () {
      final state = FilterState.defaults()
          .copyWith(orgaosSelecionados: () => {'SECOM'});
      expect(svc.apply([rec], state), isEmpty);
    });

    test('null funcao maps to NULL sentinel', () {
      final recNoFuncao = _recDurante();
      final state = FilterState.defaults()
          .copyWith(funcoesSelecionadas: () => {'NULL'});
      expect(svc.apply([recNoFuncao], state), hasLength(1));
    });
  });

  group('FilterService — name search', () {
    final rec = _rec(funcionario: 'Ranses Souza', socio: 'Ranses Souza');

    test('matching funcionario is included', () {
      final state = FilterState.defaults().copyWith(buscaNome: 'ranses');
      expect(svc.apply([rec], state), hasLength(1));
    });

    test('non-matching name is excluded', () {
      final state = FilterState.defaults().copyWith(buscaNome: 'Pedro');
      expect(svc.apply([rec], state), isEmpty);
    });

    test('empty buscaNome includes all', () {
      final state = FilterState.defaults().copyWith(buscaNome: '');
      expect(svc.apply([rec], state), hasLength(1));
    });

    test('search is case-insensitive', () {
      final state = FilterState.defaults().copyWith(buscaNome: 'RANSES');
      expect(svc.apply([rec], state), hasLength(1));
    });
  });

  group('FilterService — cycle type and score', () {
    final tri = _recDurante(index: 0);
    final quad92 = _rec(
      tipoCiclo: 'quadrado',
      scoreMatch: 92.0,
      periodoInicio: DateTime(2018, 1, 1),
      periodoFim: DateTime(2023, 1, 1),
      dataContrato: DateTime(2020, 1, 1),
      index: 1,
    );
    final quad97 = _rec(
      tipoCiclo: 'quadrado',
      scoreMatch: 97.0,
      periodoInicio: DateTime(2018, 1, 1),
      periodoFim: DateTime(2023, 1, 1),
      dataContrato: DateTime(2020, 1, 1),
      index: 2,
    );

    test('triangulo-only excludes quadrado records', () {
      final state = FilterState.defaults()
          .copyWith(incluiTriangulo: true, incluiQuadrado: false);
      final result = svc.apply([tri, quad92, quad97], state);
      expect(result, [tri]);
    });

    test('quadrado-only excludes triangulo records', () {
      final state = FilterState.defaults()
          .copyWith(incluiTriangulo: false, incluiQuadrado: true);
      final result = svc.apply([tri, quad92, quad97], state);
      expect(result.length, 2);
      expect(result.every((r) => r.tipoCiclo == 'quadrado'), isTrue);
    });

    test('score range 95–100 excludes score 92', () {
      final state = FilterState.defaults().copyWith(
        incluiTriangulo: false,
        incluiQuadrado: true,
        scoreMin: 95.0,
        scoreMax: 100.0,
      );
      final result = svc.apply([quad92, quad97], state);
      expect(result, [quad97]);
    });

    test('score filter is inactive when triangulo-only', () {
      final state = FilterState.defaults().copyWith(
        incluiTriangulo: true,
        incluiQuadrado: false,
        scoreMin: 98.0,
        scoreMax: 100.0,
      );
      expect(svc.apply([tri], state), hasLength(1));
    });
  });

  group('FilterService — financial thresholds', () {
    final cheap = _recDurante(index: 0);
    final expensive = _rec(
      valorContrato: 50000000.0,
      remuneracaoTotal: 100000.0,
      periodoInicio: DateTime(2018, 1, 1),
      periodoFim: DateTime(2023, 1, 1),
      dataContrato: DateTime(2020, 1, 1),
      index: 1,
    );

    test('default bounds include all records', () {
      final state = FilterState.defaults(
        valorContratoMax: 196489860.0,
        remuneracaoMax: 133139.43,
      );
      expect(svc.apply([cheap, expensive], state), hasLength(2));
    });

    test('valor min 10M excludes cheap record', () {
      final state = FilterState.defaults(valorContratoMax: 196489860.0)
          .copyWith(valorContratoMin: 10000000.0);
      expect(svc.apply([cheap, expensive], state), [expensive]);
    });

    test('remuneracao max 50K excludes high-salary record', () {
      final state = FilterState.defaults(remuneracaoMax: 133139.43)
          .copyWith(remuneracaoMax: 50000.0);
      expect(svc.apply([cheap, expensive], state), [cheap]);
    });
  });

  group('FilterService — sorting', () {
    final r1 = _recDurante(index: 0);
    final r2 = _rec(
      valorContrato: 200.0,
      periodoInicio: DateTime(2018, 1, 1),
      periodoFim: DateTime(2023, 1, 1),
      dataContrato: DateTime(2020, 1, 1),
      index: 1,
    );
    final r3 = _rec(
      valorContrato: 50.0,
      periodoInicio: DateTime(2018, 1, 1),
      periodoFim: DateTime(2023, 1, 1),
      dataContrato: DateTime(2020, 1, 1),
      index: 2,
    );

    test('sort by valorContrato asc', () {
      final state = FilterState.defaults().copyWith(
        sortColumn: SortColumn.valorContrato,
        sortDirection: SortDirection.asc,
      );
      final result = svc.apply([r1, r2, r3], state);
      expect(result.map((r) => r.valorContrato).toList(), [50.0, 200.0, 50000.0]);
    });

    test('sort by valorContrato desc', () {
      final state = FilterState.defaults().copyWith(
        sortColumn: SortColumn.valorContrato,
        sortDirection: SortDirection.desc,
      );
      final result = svc.apply([r1, r2, r3], state);
      expect(result.map((r) => r.valorContrato).toList(), [50000.0, 200.0, 50.0]);
    });
  });

  group('FilterService — empresa filter', () {
    test('matching empresa passes _passes', () {
      final rec = _recDurante(index: 0);
      final state = FilterState.defaults()
          .copyWith(empresasSelecionadas: () => {'Empresa Teste'});
      expect(svc.apply([rec], state), hasLength(1));
    });

    test('non-matching empresa excluded by _passes', () {
      final rec = _recDurante(index: 0);
      final state = FilterState.defaults()
          .copyWith(empresasSelecionadas: () => {'Outra Empresa'});
      expect(svc.apply([rec], state), isEmpty);
    });

    test('empresa not filtered in applyExcludingCategorical', () {
      final rec = _recDurante(index: 0);
      final state = FilterState.defaults()
          .copyWith(empresasSelecionadas: () => {'Outra Empresa'});
      expect(svc.applyExcludingCategorical([rec], state), hasLength(1));
    });
  });

  group('FilterService — temporalidade sort', () {
    // durante: months=0; apos12: months=12; antes12: months=12; antes24: months=24
    final durante = _recDurante(index: 0);
    final apos12 = _recApos(index: 1); // periodoFim=2018-01, dataContrato=2019-01 → 12 months
    final antes12 = _rec(
      periodoInicio: DateTime(2020, 1, 1),
      dataContrato: DateTime(2019, 1, 1),
      index: 2,
    ); // months=12, category=antes
    final antes24 = _recAntes(index: 3); // months=24

    test('asc: durante first, then apos before antes at same distance', () {
      final state = FilterState.defaults().copyWith(
        sortColumn: SortColumn.temporalidade,
        sortDirection: SortDirection.asc,
      );
      final result = svc.apply([apos12, antes12, durante], state);
      expect(result[0].index, 0); // durante (0 months)
      expect(result[1].index, 1); // apos12 (12 months, catOrder=1)
      expect(result[2].index, 2); // antes12 (12 months, catOrder=2)
    });

    test('desc: most distant first, durante last', () {
      final state = FilterState.defaults().copyWith(
        sortColumn: SortColumn.temporalidade,
        sortDirection: SortDirection.desc,
      );
      final result = svc.apply([durante, apos12, antes24], state);
      expect(result[0].index, 3); // antes24 (most distant)
      expect(result[1].index, 1); // apos12
      expect(result[2].index, 0); // durante last
    });

    test('automatic tiebreaker: same scoreMatch ordered by temporal distance asc', () {
      final near = _rec(
        tipoCiclo: 'quadrado',
        scoreMatch: 95.0,
        periodoInicio: DateTime(2018, 1, 1),
        periodoFim: DateTime(2023, 1, 1),
        dataContrato: DateTime(2020, 1, 1), // durante, months=0
        index: 0,
      );
      final far = _rec(
        tipoCiclo: 'quadrado',
        scoreMatch: 95.0,
        periodoInicio: DateTime(2015, 1, 1),
        periodoFim: DateTime(2018, 1, 1),
        dataContrato: DateTime(2019, 1, 1), // apos, months=12
        index: 1,
      );
      final state = FilterState.defaults().copyWith(
        sortColumn: SortColumn.scoreMatch,
        sortDirection: SortDirection.desc,
      );
      final result = svc.apply([far, near], state);
      expect(result[0].index, 0); // near (durante, 0 months) wins tiebreaker
      expect(result[1].index, 1); // far (apos, 12 months)
    });
  });
}
