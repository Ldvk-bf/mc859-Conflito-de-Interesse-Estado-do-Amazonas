import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/favorite_company_summary.dart';
import '../models/favorite_orgao_summary.dart';
import '../providers/data_provider.dart';
import '../providers/filter_provider.dart';
import '../services/export_service.dart';
import '../widgets/anonymize_toggle_button.dart';
import '../services/filter_service.dart';
import '../widgets/result_list_item.dart';
import '../widgets/sortable_column_header.dart';
import '../widgets/favorite_company_card.dart';
import '../widgets/favorite_orgao_card.dart';
import 'company_detail_screen.dart';
import 'orgao_detail_screen.dart';

enum FavoritesSegment { pessoas, empresas, orgaos }

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  FavoritesSegment _selectedSegment = FavoritesSegment.pessoas;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favoritos'),
        actions: [
          const AnonymizeToggleButton(),
          if (_selectedSegment == FavoritesSegment.pessoas)
            _ShareButton(),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<FavoritesSegment>(
              segments: const [
                ButtonSegment(
                  value: FavoritesSegment.pessoas,
                  label: Text('Pessoas'),
                  icon: Icon(Icons.person),
                ),
                ButtonSegment(
                  value: FavoritesSegment.empresas,
                  label: Text('Empresas'),
                  icon: Icon(Icons.business),
                ),
                ButtonSegment(
                  value: FavoritesSegment.orgaos,
                  label: Text('Órgãos'),
                  icon: Icon(Icons.account_balance),
                ),
              ],
              selected: {_selectedSegment},
              onSelectionChanged: (s) =>
                  setState(() => _selectedSegment = s.first),
            ),
          ),
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_selectedSegment) {
      case FavoritesSegment.pessoas:
        return _PessoasTab();
      case FavoritesSegment.empresas:
        return _EmpresasTab(
          onTap: (summary) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CompanyDetailScreen(summary: summary),
            ),
          ),
        );
      case FavoritesSegment.orgaos:
        return _OrgaosTab(
          onTap: (summary) => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => OrgaoDetailScreen(summary: summary),
            ),
          ),
        );
    }
  }
}

class _ShareButton extends StatefulWidget {
  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  final _key = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final filter = context.watch<FilterProvider>();
    final sorted =
        FilterService().sortFavorites(data.favoriteRecords, filter.state);
    if (sorted.isEmpty) return const SizedBox.shrink();
    return IconButton(
      key: _key,
      icon: const Icon(Icons.share),
      tooltip: 'Exportar favoritos',
      onPressed: () async {
        final box = _key.currentContext?.findRenderObject() as RenderBox?;
        final origin =
            box != null ? box.localToGlobal(Offset.zero) & box.size : null;
        try {
          await ExportService().export(
            sorted,
            'favoritos_conflito',
            sharePositionOrigin: origin,
          );
        } catch (e, st) {
          debugPrint('[SHARE_ERROR] ${e.runtimeType}: $e\n$st');
          if (!context.mounted) return;
          final msg = e is PlatformException
              ? 'Não foi possível abrir o compartilhamento. Tente novamente.'
              : 'Erro ao gerar o arquivo CSV. Tente novamente.';
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(msg)));
        }
      },
    );
  }
}

class _PessoasTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final filter = context.watch<FilterProvider>();
    final sorted =
        FilterService().sortFavorites(data.favoriteRecords, filter.state);

    if (sorted.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.star_border, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Nenhum favorito ainda.'),
          ],
        ),
      );
    }

    return Column(
      children: [
        SortableColumnHeader(
          activeColumn: filter.state.favoriteSortColumn,
          activeDirection: filter.state.favoriteSortDirection,
          onTap: filter.updateFavoriteSort,
        ),
        Expanded(
          child: ListView.builder(
            itemCount: sorted.length,
            itemBuilder: (_, i) => ResultListItem(record: sorted[i]),
          ),
        ),
      ],
    );
  }
}

class _EmpresasTab extends StatelessWidget {
  final void Function(FavoriteCompanySummary summary) onTap;

  const _EmpresasTab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final companies = data.favoriteCompanies;

    if (companies.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Favorite pessoas para ver as empresas aqui.'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: companies.length,
      itemBuilder: (_, i) => FavoriteCompanyCard(
        summary: companies[i],
        onTap: () => onTap(companies[i]),
      ),
    );
  }
}

class _OrgaosTab extends StatelessWidget {
  final void Function(FavoriteOrgaoSummary summary) onTap;

  const _OrgaosTab({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final data = context.watch<DataProvider>();
    final orgaos = data.favoriteOrgaos;

    if (orgaos.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_balance_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Favorite pessoas para ver os órgãos aqui.'),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: orgaos.length,
      itemBuilder: (_, i) => FavoriteOrgaoCard(
        summary: orgaos[i],
        onTap: () => onTap(orgaos[i]),
      ),
    );
  }
}
