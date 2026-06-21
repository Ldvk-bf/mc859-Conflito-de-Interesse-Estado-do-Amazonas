import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/data_provider.dart';
import 'providers/filter_provider.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => DataProvider()..init(),
      child: const ConflittoApp(),
    ),
  );
}

class ConflittoApp extends StatelessWidget {
  const ConflittoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProxyProvider<DataProvider, FilterProvider>(
      create: (ctx) => FilterProvider(ctx.read<DataProvider>()),
      update: (_, data, prev) => prev ?? FilterProvider(data),
      child: MaterialApp(
        title: 'Conflito de Interesse',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1B5E20),
          ),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}
