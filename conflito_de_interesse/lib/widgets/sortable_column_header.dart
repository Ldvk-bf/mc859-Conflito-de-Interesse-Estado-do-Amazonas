import 'package:flutter/material.dart';
import '../models/filter_state.dart';

class SortableColumnHeader extends StatelessWidget {
  final SortColumn activeColumn;
  final SortDirection activeDirection;
  final void Function(SortColumn) onTap;

  const SortableColumnHeader({
    super.key,
    required this.activeColumn,
    required this.activeDirection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          _SortChip(
            label: 'Funcionário',
            column: SortColumn.funcionario,
            activeColumn: activeColumn,
            activeDirection: activeDirection,
            onTap: () => onTap(SortColumn.funcionario),
          ),
          _SortChip(
            label: 'Valor',
            column: SortColumn.valorContrato,
            activeColumn: activeColumn,
            activeDirection: activeDirection,
            onTap: () => onTap(SortColumn.valorContrato),
          ),
          _SortChip(
            label: 'Temporalidade',
            column: SortColumn.temporalidade,
            activeColumn: activeColumn,
            activeDirection: activeDirection,
            onTap: () => onTap(SortColumn.temporalidade),
          ),
          _SortChip(
            label: 'Score',
            column: SortColumn.scoreMatch,
            activeColumn: activeColumn,
            activeDirection: activeDirection,
            onTap: () => onTap(SortColumn.scoreMatch),
          ),
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final SortColumn column;
  final SortColumn activeColumn;
  final SortDirection activeDirection;
  final VoidCallback onTap;

  const _SortChip({
    required this.label,
    required this.column,
    required this.activeColumn,
    required this.activeDirection,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = activeColumn == column;
    final icon = !isActive
        ? Icons.unfold_more
        : activeDirection == SortDirection.asc
            ? Icons.expand_less
            : Icons.expand_more;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight:
                            isActive ? FontWeight.bold : FontWeight.normal,
                      ),
                ),
              ),
              Icon(icon, size: 14),
            ],
          ),
        ),
      ),
    );
  }
}
