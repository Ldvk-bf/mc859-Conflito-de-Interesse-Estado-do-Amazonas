import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';
import 'analytics_screen.dart';
import 'results_screen.dart';
import 'favorites_screen.dart';
import 'export_basket_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();

    if (data.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _tabIndex,
        children: [
          const ResultsScreen(),
          const FavoritesScreen(),
          const ExportBasketScreen(),
          AnalyticsScreen(isActive: _tabIndex == 3),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Resultados',
          ),
          const NavigationDestination(
            icon: Icon(Icons.star),
            label: 'Favoritos',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: data.basketCount > 0,
              label: Text('${data.basketCount}'),
              child: const Icon(Icons.download),
            ),
            label: 'Exportar',
          ),
          const NavigationDestination(
            icon: Icon(Icons.bar_chart),
            label: 'Análise',
          ),
        ],
      ),
    );
  }
}
