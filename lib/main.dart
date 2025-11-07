import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/login_screen.dart';
import 'screens/search_screen.dart';


void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TLC DRAWINGS SEARCH APP',
      theme: ThemeData(primarySwatch: Colors.red), // Bordeaux theme
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/main': (context) => LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 800; // adjust threshold as needed
            if (isDesktop) {
              // Desktop UI not implemented yet - fall back to the existing SearchScreen
              return const SearchScreen();
            }
            return const SearchScreen(); // Mobile UI hiện tại
          },
        ),
      },
    );
  }
}