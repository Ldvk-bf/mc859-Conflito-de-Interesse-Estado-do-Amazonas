import 'package:flutter/material.dart';

class SearchableChecklist extends StatefulWidget {
  final String title;
  final Set<String> allOptions;
  // null = no filter (all pass); {} = nothing passes; non-empty = filter to these
  final Set<String>? selected;
  final ValueChanged<Set<String>?> onChanged;
  final String? emptyLabel;

  const SearchableChecklist({
    super.key,
    required this.title,
    required this.allOptions,
    required this.selected,
    required this.onChanged,
    this.emptyLabel,
  });

  @override
  State<SearchableChecklist> createState() => _SearchableChecklistState();
}

class _SearchableChecklistState extends State<SearchableChecklist> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final sorted = widget.allOptions.toList()..sort();
    final filtered = _query.isEmpty
        ? sorted
        : sorted
            .where((s) => s.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    final allSelected = widget.selected == null;
    final selectedCount =
        allSelected ? widget.allOptions.length : widget.selected!.length;

    if (widget.allOptions.isEmpty && widget.emptyLabel != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(
          widget.emptyLabel!,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
              ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          decoration: InputDecoration(
            hintText: 'Buscar ${widget.title.toLowerCase()}...',
            prefixIcon: const Icon(Icons.search, size: 18),
            isDense: true,
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          ),
          onChanged: (v) => setState(() => _query = v),
        ),
        Row(
          children: [
            TextButton(
              onPressed: () => widget.onChanged(null), // null = no filter
              child: const Text('Todos'),
            ),
            TextButton(
              onPressed: () =>
                  widget.onChanged(<String>{}), // {} = nothing passes
              child: const Text('Nenhum'),
            ),
            Expanded(
              child: Text(
                '$selectedCount de ${widget.allOptions.length}',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 200),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: filtered.length,
            itemBuilder: (_, i) {
              final opt = filtered[i];
              final checked = allSelected || widget.selected!.contains(opt);
              return CheckboxListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                title: Text(opt, style: const TextStyle(fontSize: 13)),
                value: checked,
                onChanged: (_) {
                  final Set<String> next;
                  if (allSelected) {
                    // All were checked — unchecking one item selects all except it
                    next = Set<String>.from(widget.allOptions)..remove(opt);
                  } else {
                    final base = Set<String>.from(widget.selected!);
                    if (checked) {
                      base.remove(opt);
                    } else {
                      base.add(opt);
                    }
                    next = base;
                  }
                  // Normalize: full set == no filter (null)
                  widget.onChanged(
                    next.length == widget.allOptions.length ? null : next,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
