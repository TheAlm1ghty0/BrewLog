import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart'; // Import new provider
import 'services/auth_service.dart';    // Import for LocalAuthentication
import 'package:local_auth/local_auth.dart'; // Import for LocalAuthentication

void main() {
  runApp(
    // Wrap with MultiProvider
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()), // Use AuthProvider without constructor args now
        ChangeNotifierProvider(create: (_) => ThemeProvider()), // Add ThemeProvider
      ],
      child: const DrinkTrackerApp(),
    ),
  );
}

class DrinkTrackerApp extends StatelessWidget {
  const DrinkTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Consume the ThemeProvider
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          title: 'BrewLog',
          // Use the themes from the provider
          theme: themeProvider.lightTheme,
          darkTheme: themeProvider.darkTheme,
          themeMode: themeProvider.themeMode,
          home: const AuthCheck(),
        );
      },
    );
  }
}

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  @override
  void initState() {
    super.initState();
    // Use listen: false in initState
    Provider.of<AuthProvider>(context, listen: false).checkAuth();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.isAuthenticated) {
          return const HomeScreen();
        } else {
          // LoginScreen can access AuthProvider via Provider.of, no need to pass it.
          return const LoginScreen(); // Removed the parameter
        }
      },
    );
  }
}

