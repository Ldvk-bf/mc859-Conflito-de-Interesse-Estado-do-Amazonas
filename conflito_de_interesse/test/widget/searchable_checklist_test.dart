import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:conflito_de_interesse/widgets/searchable_checklist.dart';

Widget _wrap({
  required Set<String> allOptions,
  required Set<String>? selected,
  required ValueChanged<Set<String>?> onChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SearchableChecklist(
        title: 'Teste',
        allOptions: allOptions,
        selected: selected,
        onChanged: onChanged,
      ),
    ),
  );
}

void main() {
  final options = {'Alpha', 'Beta', 'Gamma', 'Delta'};

  testWidgets('renders search field and all options', (tester) async {
    await tester.pumpWidget(_wrap(
      allOptions: options,
      selected: null,
      onChanged: (_) {},
    ));
    expect(find.byType(TextField), findsOneWidget);
    for (final opt in options) {
      expect(find.text(opt), findsOneWidget);
    }
  });

  testWidgets('search field filters visible options', (tester) async {
    await tester.pumpWidget(_wrap(
      allOptions: options,
      selected: null,
      onChanged: (_) {},
    ));
    await tester.enterText(find.byType(TextField), 'Al');
    await tester.pump();
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
  });

  testWidgets('Todos button calls onChanged with null', (tester) async {
    Set<String>? result = {'Alpha'};
    await tester.pumpWidget(_wrap(
      allOptions: options,
      selected: {'Alpha'},
      onChanged: (v) => result = v,
    ));
    await tester.tap(find.text('Todos'));
    await tester.pump();
    expect(result, isNull);
  });

  testWidgets('Nenhum button calls onChanged with empty set', (tester) async {
    Set<String>? result;
    await tester.pumpWidget(_wrap(
      allOptions: options,
      selected: null, // start with "all selected"
      onChanged: (v) => result = v,
    ));
    await tester.tap(find.text('Nenhum'));
    await tester.pump();
    expect(result, isNotNull);
    expect(result, isEmpty);
  });

  testWidgets('all options checked when selected is null', (tester) async {
    await tester.pumpWidget(_wrap(
      allOptions: options,
      selected: null,
      onChanged: (_) {},
    ));
    final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(checkboxes.every((c) => c.value == true), isTrue);
  });

  testWidgets('no options checked when selected is empty set', (tester) async {
    await tester.pumpWidget(_wrap(
      allOptions: options,
      selected: <String>{},
      onChanged: (_) {},
    ));
    final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
    expect(checkboxes.every((c) => c.value == false), isTrue);
  });
}
