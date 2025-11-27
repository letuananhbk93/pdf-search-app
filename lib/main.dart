import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/search_screen.dart';
import 'screens/colors_screen.dart';
import 'screens/dims_screen.dart';


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
        '/main': (context) => const HomeScreen(),
        '/search': (context) => const SearchScreen(),
        '/colors': (context) => const ColorsScreen(),
        '/dims': (context) => const DimsScreen(),
      },
    );
  }
}