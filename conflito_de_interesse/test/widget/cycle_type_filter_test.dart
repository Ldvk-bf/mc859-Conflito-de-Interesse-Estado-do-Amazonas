import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:conflito_de_interesse/providers/data_provider.dart';
import 'package:conflito_de_interesse/providers/filter_provider.dart';
import 'package:conflito_de_interesse/widgets/cycle_type_filter.dart';

Widget _wrap(Widget child) {
  final data = DataProvider();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: data),
      ChangeNotifierProvider(create: (_) => FilterProvider(data)),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  testWidgets('CycleTypeFilter renders two FilterChips', (tester) async {
    await tester.pumpWidget(_wrap(const CycleTypeFilter()));
    expect(find.byType(FilterChip), findsNWidgets(2));
  });

  testWidgets('Both chips selected by default', (tester) async {
    await tester.pumpWidget(_wrap(const CycleTypeFilter()));
    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
    expect(chips.every((c) => c.selected), isTrue);
  });

  testWidgets('Deselecting Quadrado chip updates state', (tester) async {
    await tester.pumpWidget(_wrap(const CycleTypeFilter()));
    await tester.tap(find.text('Quadrado (similaridade)'));
    await tester.pump();
    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip)).toList();
    expect(chips[0].selected, isTrue);  // Triângulo still selected
    expect(chips[1].selected, isFalse); // Quadrado deselected
  });

  testWidgets('Cannot deselect both chips (at-least-one constraint)', (tester) async {
    await tester.pumpWidget(_wrap(const CycleTypeFilter()));
    // Deselect Triangulo
    await tester.tap(find.text('Triângulo (exato)'));
    await tester.pump();
    // Try to also deselect Quadrado — FilterProvider blocks this
    await tester.tap(find.text('Quadrado (similaridade)'));
    await tester.pump();
    final chips = tester.widgetList<FilterChip>(find.byType(FilterChip)).toList();
    // At least one must remain selected
    expect(chips.any((c) => c.selected), isTrue);
  });
}
