import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:conflito_de_interesse/models/filter_state.dart';
import 'package:conflito_de_interesse/providers/data_provider.dart';
import 'package:conflito_de_interesse/providers/filter_provider.dart';
import 'package:conflito_de_interesse/screens/favorites_screen.dart';
import 'package:conflito_de_interesse/widgets/sortable_column_header.dart';

Widget _wrap() {
  final data = DataProvider();
  final filter = FilterProvider(data);
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: data),
      ChangeNotifierProvider.value(value: filter),
    ],
    child: const MaterialApp(home: FavoritesScreen()),
  );
}

void main() {
  group('FavoritesScreen — empty state', () {
    testWidgets('shows empty message when no favorites', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.text('Nenhum favorito ainda.'), findsOneWidget);
    });

    testWidgets('no sort header when favorites list is empty', (tester) async {
      await tester.pumpWidget(_wrap());
      expect(find.byType(SortableColumnHeader), findsNothing);
    });
  });

  group('SortableColumnHeader — favorites state wiring', () {
    testWidgets('favorites header uses favoriteSortColumn state', (tester) async {
      final data = DataProvider();
      final filter = FilterProvider(data);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: filter,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer<FilterProvider>(
                builder: (_, f, _) => SortableColumnHeader(
                  activeColumn: f.state.favoriteSortColumn,
                  activeDirection: f.state.favoriteSortDirection,
                  onTap: f.updateFavoriteSort,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Funcionário'), findsOneWidget);
      expect(find.text('Score'), findsOneWidget);
    });

    testWidgets('tapping Funcionário calls updateFavoriteSort', (tester) async {
      final data = DataProvider();
      final filter = FilterProvider(data);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: filter,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer<FilterProvider>(
                builder: (_, f, _) => SortableColumnHeader(
                  activeColumn: f.state.favoriteSortColumn,
                  activeDirection: f.state.favoriteSortDirection,
                  onTap: f.updateFavoriteSort,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Funcionário'));
      await tester.pump();
      expect(filter.state.favoriteSortColumn, SortColumn.funcionario);
      // main sort is unchanged
      expect(filter.state.sortColumn, SortColumn.scoreMatch);
    });
  });
}
