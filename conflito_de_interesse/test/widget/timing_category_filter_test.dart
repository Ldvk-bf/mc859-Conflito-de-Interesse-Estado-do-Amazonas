import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conflito_de_interesse/models/conflito_record.dart';
import 'package:conflito_de_interesse/models/filter_state.dart';
import 'package:conflito_de_interesse/widgets/filters/timing_category_filter.dart';

void main() {
  group('TimingCategoryFilter', () {
    Set<TimingCategory>? lastEmitted;

    Widget build(Set<TimingCategory> selected) {
      return MaterialApp(
        home: Scaffold(
          body: TimingCategoryFilter(
            selected: selected,
            onChanged: (cats) => lastEmitted = cats,
            selectedDistances: TimingDistanceBand.values.toSet(),
            onDistanceChanged: (_) {},
          ),
        ),
      );
    }

    setUp(() => lastEmitted = null);

    testWidgets('renders 3 category checkboxes when only durante selected', (tester) async {
      await tester.pumpWidget(build({TimingCategory.durante}));
      expect(find.byType(CheckboxListTile), findsNWidgets(3));
    });

    testWidgets('renders 3+4 checkboxes when antes/apos selected', (tester) async {
      await tester.pumpWidget(build(TimingCategory.values.toSet()));
      // 3 category + 4 distance band checkboxes
      expect(find.byType(CheckboxListTile), findsNWidgets(7));
    });

    testWidgets('all selected by default → category checkboxes all checked', (tester) async {
      await tester.pumpWidget(build(TimingCategory.values.toSet()));
      final tiles = tester.widgetList<CheckboxListTile>(
          find.byType(CheckboxListTile)).toList();
      // First 3 are category tiles, all should be checked
      expect(tiles.take(3).every((t) => t.value == true), isTrue);
    });

    testWidgets('unchecked category → not checked', (tester) async {
      await tester.pumpWidget(build({TimingCategory.antes, TimingCategory.apos}));
      final tiles = tester.widgetList<CheckboxListTile>(
          find.byType(CheckboxListTile)).toList();
      // during is index 0 (TimingCategory.values order: durante, antes, apos)
      expect(tiles[0].value, isFalse);
      expect(tiles[1].value, isTrue);
      expect(tiles[2].value, isTrue);
    });

    testWidgets('tapping durante removes it from emitted set', (tester) async {
      await tester.pumpWidget(build(TimingCategory.values.toSet()));
      await tester.tap(find.text('Durante o vínculo'));
      await tester.pump();
      expect(lastEmitted, isNotNull);
      expect(lastEmitted!.contains(TimingCategory.durante), isFalse);
      expect(lastEmitted!.contains(TimingCategory.antes), isTrue);
      expect(lastEmitted!.contains(TimingCategory.apos), isTrue);
    });

    testWidgets('tapping antes twice emits set with antes then without', (tester) async {
      await tester.pumpWidget(build(TimingCategory.values.toSet()));
      // Remove antes
      await tester.tap(find.text('Antes do vínculo'));
      await tester.pump();
      expect(lastEmitted!.contains(TimingCategory.antes), isFalse);

      // Add antes back (simulate parent rebuild with new set)
      await tester.pumpWidget(
          build({TimingCategory.durante, TimingCategory.apos}));
      await tester.tap(find.text('Antes do vínculo'));
      await tester.pump();
      expect(lastEmitted!.contains(TimingCategory.antes), isTrue);
    });

    testWidgets('can emit empty set', (tester) async {
      await tester.pumpWidget(build({TimingCategory.durante}));
      await tester.tap(find.text('Durante o vínculo'));
      await tester.pump();
      expect(lastEmitted, isEmpty);
    });
  });
}
