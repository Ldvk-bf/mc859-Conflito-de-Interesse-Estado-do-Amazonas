import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:conflito_de_interesse/providers/data_provider.dart';
import 'package:conflito_de_interesse/providers/filter_provider.dart';
import 'package:conflito_de_interesse/widgets/score_range_filter.dart';

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
  testWidgets('ScoreRangeFilter renders RangeSlider', (tester) async {
    await tester.pumpWidget(_wrap(const ScoreRangeFilter()));
    expect(find.byType(RangeSlider), findsOneWidget);
  });

  testWidgets('ScoreRangeFilter shows 92–100 label by default', (tester) async {
    await tester.pumpWidget(_wrap(const ScoreRangeFilter()));
    expect(find.textContaining('92'), findsWidgets);
    expect(find.textContaining('100'), findsWidgets);
  });

  testWidgets('ScoreRangeFilter shows disabled hint when quadrado inactive',
      (tester) async {
    final data = DataProvider();
    final filterProvider = FilterProvider(data);
    filterProvider.updateCycleAndScore(triangulo: true, quadrado: false);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: data),
          ChangeNotifierProvider.value(value: filterProvider),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ScoreRangeFilter()),
        ),
      ),
    );

    expect(find.textContaining('Ative'), findsOneWidget);
  });
}
