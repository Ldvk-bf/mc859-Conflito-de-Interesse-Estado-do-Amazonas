import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/filter_provider.dart';

class NameSearchFilter extends StatefulWidget {
  const NameSearchFilter({super.key});

  @override
  State<NameSearchFilter> createState() => _NameSearchFilterState();
}

class _NameSearchFilterState extends State<NameSearchFilter> {
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: context.read<FilterProvider>().state.buscaNome,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _ctrl,
      decoration: InputDecoration(
        hintText: 'Buscar por funcionário ou sócio...',
        prefixIcon: const Icon(Icons.search),
        border: const OutlineInputBorder(),
        suffixIcon: _ctrl.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _ctrl.clear();
                  context.read<FilterProvider>().updateNameSearch('');
                },
              )
            : null,
      ),
      onChanged: (v) {
        setState(() {});
        context.read<FilterProvider>().updateNameSearch(v);
      },
    );
  }
}
