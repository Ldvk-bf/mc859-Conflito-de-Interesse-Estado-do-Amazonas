import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_provider.dart';

class AnonymizeToggleButton extends StatelessWidget {
  const AnonymizeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final anonymized = context.watch<DataProvider>().anonymized;
    return IconButton(
      icon: Icon(anonymized ? Icons.visibility_off : Icons.visibility),
      tooltip: anonymized ? 'Revelar nomes' : 'Ocultar nomes',
      onPressed: () => context.read<DataProvider>().toggleAnonymization(),
    );
  }
}
