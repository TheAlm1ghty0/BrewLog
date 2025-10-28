import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/leaderboard.dart';

class ShareLeaderboardScreen extends StatelessWidget {
  final Leaderboard leaderboard;

  const ShareLeaderboardScreen({super.key, required this.leaderboard});

  @override
  Widget build(BuildContext context) {
    // Data for QR code remains the full link for direct scanning action
    final String deepLinkData = "drinkleaderboard://join?code=${leaderboard.inviteCode}";
    // Data to display and copy is just the code
    final String inviteCodeOnly = leaderboard.inviteCode; // Use the UUID string directly

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite to Leaderboard'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Scan QR code to join', // Simplified instruction
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                leaderboard.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // QR Code still uses the full deeplink
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white, // Keep white background for QR
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ]
                ),
                child: QrImageView(
                  data: deepLinkData,
                  version: QrVersions.auto,
                  size: 250.0,
                  gapless: false, // Ensure gaps for better scanning
                  errorStateBuilder: (cxt, err) {
                    return const Center(
                      child: Text("Uh oh! Something went wrong generating the QR code.", textAlign: TextAlign.center),
                    );
                  },

                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Or share the invite code below:', // Updated text
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              // Copy button copies only the code
              TextButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy Invite Code'), // Updated label
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: inviteCodeOnly)); // Copy only UUID
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invite code copied to clipboard!')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}