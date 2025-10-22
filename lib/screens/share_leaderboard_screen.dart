import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/leaderboard.dart';

class ShareLeaderboardScreen extends StatelessWidget {
  final Leaderboard leaderboard;

  const ShareLeaderboardScreen({super.key, required this.leaderboard});

  @override
  Widget build(BuildContext context) {
    final String deepLinkData = "drinkleaderboard://join?code=${leaderboard.inviteCode}";

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
                'Scan this code to join the',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                leaderboard.name,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white, // Hardcoded for maximum QR code scannability
                  borderRadius: BorderRadius.circular(16),
                ),
                child: QrImageView(
                  data: deepLinkData,
                  version: QrVersions.auto,
                  size: 250.0,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Or share the link below:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                icon: const Icon(Icons.copy),
                label: const Text('Copy Join Link'),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: deepLinkData));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Join link copied to clipboard!')),
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