import 'package:flutter/material.dart';
import 'home_screen.dart'; // make sure you created this file

void main() {
  runApp(const DrinkTrackerApp());
}

class DrinkTrackerApp extends StatelessWidget {
  const DrinkTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drink Tracker',
      theme: ThemeData.light(),   // default light theme
      darkTheme: ThemeData.dark(), // dark theme
      themeMode: ThemeMode.dark,   // force dark mode for now
      home: const HomeScreen(),
    );
  }
}