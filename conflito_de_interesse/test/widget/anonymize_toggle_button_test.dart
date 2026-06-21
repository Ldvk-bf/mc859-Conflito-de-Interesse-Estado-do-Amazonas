import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:conflito_de_interesse/providers/data_provider.dart';
import 'package:conflito_de_interesse/widgets/anonymize_toggle_button.dart';

Widget _wrap(DataProvider provider) => ChangeNotifierProvider<DataProvider>.value(
      value: provider,
      child: MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            actions: const [AnonymizeToggleButton()],
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );

void main() {
  group('AnonymizeToggleButton', () {
    testWidgets('shows visibility_off icon when anonymized=true', (tester) async {
      final provider = DataProvider();
      expect(provider.anonymized, isTrue);

      await tester.pumpWidget(_wrap(provider));

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
      expect(find.byIcon(Icons.visibility), findsNothing);
    });

    testWidgets('shows visibility icon when anonymized=false', (tester) async {
      final provider = DataProvider();
      provider.toggleAnonymization();
      expect(provider.anonymized, isFalse);

      await tester.pumpWidget(_wrap(provider));

      expect(find.byIcon(Icons.visibility), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off), findsNothing);
    });

    testWidgets('tapping calls toggleAnonymization and icon updates', (tester) async {
      final provider = DataProvider();
      await tester.pumpWidget(_wrap(provider));

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);

      await tester.tap(find.byType(AnonymizeToggleButton));
      await tester.pump();

      expect(provider.anonymized, isFalse);
      expect(find.byIcon(Icons.visibility), findsOneWidget);
    });

    testWidgets('tooltip is Revelar nomes when anonymized=true', (tester) async {
      final provider = DataProvider();
      await tester.pumpWidget(_wrap(provider));

      final btn = tester.widget<IconButton>(find.byType(IconButton));
      expect(btn.tooltip, 'Revelar nomes');
    });

    testWidgets('tooltip is Ocultar nomes when anonymized=false', (tester) async {
      final provider = DataProvider();
      provider.toggleAnonymization();
      await tester.pumpWidget(_wrap(provider));

      final btn = tester.widget<IconButton>(find.byType(IconButton));
      expect(btn.tooltip, 'Ocultar nomes');
    });
  });
}
