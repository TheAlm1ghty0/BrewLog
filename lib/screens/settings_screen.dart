import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart'; // Import for biometrics
import '../providers/auth_provider.dart';
import '../services/auth_service.dart'; // Import AuthService
import 'manage_leaderboards_screen.dart';
import 'profile_screen.dart';
import 'appearance_screen.dart'; // Import the new screen

class SettingsScreen extends StatefulWidget {
  final VoidCallback onDataChanged;

  const SettingsScreen({super.key, required this.onDataChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Use AuthService from AuthProvider or create instance carefully
  late AuthService _authService;
  bool _deviceSupportsBiometrics = false;

  @override
  void initState() {
    super.initState();
    // Get AuthService instance properly
    // Option 1: Access via Provider (if AuthProvider exposes it)
    // _authService = Provider.of<AuthProvider>(context, listen: false).authService;
    // Option 2: Create instance (ensure LocalAuthentication is passed)
    _authService = AuthService(LocalAuthentication()); // Assuming this is how it's constructed
    _checkBiometricSupport();
  }

  Future<void> _checkBiometricSupport() async {
    bool supported = await _authService.isDeviceSupported();
    if (mounted) {
      setState(() => _deviceSupportsBiometrics = supported);
    }
  }


  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authProvider = Provider.of<AuthProvider>(context); // Listen for changes

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Column(
        children: [
          // Main settings options
          ListView(
            shrinkWrap: true,
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Profile'),
                subtitle: const Text('Change your username or password'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const ProfileScreen(),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.palette_outlined),
                title: const Text('Appearance'),
                subtitle: const Text('Customize the app\'s theme'),
                onTap: () {
                  // Navigate to the new Appearance screen
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const AppearanceScreen()),
                  );
                },
              ),
              // --- Biometrics Switch (only show if supported) ---
              if (_deviceSupportsBiometrics)
                SwitchListTile(
                  secondary: const Icon(Icons.fingerprint),
                  title: const Text('Enable Biometric Login'),
                  value: authProvider.isBiometricsGloballyEnabled,
                  onChanged: (bool value) async {
                    if (value) {
                      // Try to authenticate before enabling
                      bool didAuthenticate = await _authService.authenticateWithBiometrics(
                          'Please authenticate to enable biometric login.'
                      );
                      if (didAuthenticate && mounted) {
                        authProvider.setBiometricPreference(true);
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Biometric authentication failed. Could not enable.')),
                        );
                      }
                    } else {
                      // Directly disable
                      authProvider.setBiometricPreference(false);
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.leaderboard_outlined),
                title: const Text('Leaderboards'),
                subtitle: const Text('Leave or delete your leaderboards'),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ManageLeaderboardsScreen(onDataChanged: widget.onDataChanged),
                    ),
                  );
                },
              ),
            ],
          ),

          const Spacer(), // Pushes the logout button to the bottom

          // Logout button is always at the bottom
          const Divider(height: 0),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                // Use Material 3 error colors for destructive actions
                backgroundColor: colorScheme.errorContainer,
                foregroundColor: colorScheme.onErrorContainer,
              ),
              onPressed: () async { // Make async for logout
                await authProvider.logout(); // Await the logout process
                // Ensure navigation happens after logout completes
                if (mounted) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}