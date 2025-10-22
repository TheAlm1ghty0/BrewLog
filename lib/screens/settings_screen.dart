import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:awesome_dialog/awesome_dialog.dart'; // <-- NEW IMPORT
import '../providers/auth_provider.dart';
import '../services/auth_service.dart'; // <-- NEW IMPORT
import 'manage_leaderboards_screen.dart';
import 'profile_screen.dart';

class SettingsScreen extends StatelessWidget {
  final VoidCallback onDataChanged;

  const SettingsScreen({super.key, required this.onDataChanged});

  // --- NEW: Biometrics Toggle Logic ---
  void _toggleBiometrics(BuildContext context, AuthProvider auth, bool isEnabled) {
    final authService = AuthService(); // We need this to prompt for fingerprint
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (isEnabled) {
      // If turning ON, we must get a fingerprint scan to confirm.
      AwesomeDialog(
        context: context,
        dialogType: DialogType.noHeader,
        animType: AnimType.bottomSlide,
        title: 'Enable Biometric Login',
        desc: 'Please scan your fingerprint to confirm you want to enable biometric login.',
        btnCancelOnPress: () {},
        btnOkText: 'Scan',
        btnOkOnPress: () async {
          final bool didAuth = await authService.authenticateWithBiometrics(
            'Scan to enable biometric login',
          );
          if (didAuth) {
            await auth.setBiometricsEnabled(true);
            if (context.mounted) {
              scaffoldMessenger.showSnackBar(
                const SnackBar(content: Text('Biometric Login Enabled!')),
              );
            }
          } else if (context.mounted) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text('Authentication failed.', style: TextStyle(color: colorScheme.onError)),
                backgroundColor: colorScheme.error,
              ),
            );
          }
        },
      ).show();
    } else {
      // If turning OFF, just do it. No extra auth needed.
      auth.setBiometricsEnabled(false);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Biometric Login Disabled.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    // We use a Consumer here to get auth state and rebuild when it changes
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Theme customization coming soon!')),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.leaderboard_outlined),
                    title: const Text('Leaderboards'),
                    subtitle: const Text('Leave or delete your leaderboards'),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => ManageLeaderboardsScreen(onDataChanged: onDataChanged),
                        ),
                      );
                    },
                  ),

                  // --- NEW: Biometric Toggle (PWA-SAFE) ---
                  // This will only be visible if the device supports biometrics
                  if (auth.isBiometricsSupported)
                    SwitchListTile(
                      secondary: const Icon(Icons.fingerprint),
                      title: const Text('Enable Biometric Login'),
                      subtitle: const Text('Use your fingerprint to log in'),
                      value: auth.isBiometricsEnabled,
                      onChanged: (bool isEnabled) {
                        _toggleBiometrics(context, auth, isEnabled);
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
                    backgroundColor: colorScheme.errorContainer,
                    foregroundColor: colorScheme.onErrorContainer,
                  ),
                  onPressed: () {
                    auth.logout(); // Use the provider's logout method
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}