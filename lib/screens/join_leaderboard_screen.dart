import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';

class JoinLeaderboardScreen extends StatefulWidget {
  const JoinLeaderboardScreen({super.key});

  @override
  State<JoinLeaderboardScreen> createState() => _JoinLeaderboardScreenState();
}

class _JoinLeaderboardScreenState extends State<JoinLeaderboardScreen> {
  final ApiService _apiService = ApiService();
  final _linkController = TextEditingController();
  bool _isProcessing = false;

  void _processJoinLink(String? link) {
    if (_isProcessing || link == null || link.isEmpty) return;

    if (link.startsWith('drinkleaderboard://join?code=')) {
      setState(() {
        _isProcessing = true;
      });

      final uri = Uri.parse(link);
      final inviteCode = uri.queryParameters['code'];

      if (inviteCode != null && inviteCode.isNotEmpty) {
        _joinLeaderboard(inviteCode);
      } else {
        _showError('Invalid join link format.');
      }
    } else {
      _showError('This is not a valid Drink Leaderboard invite link.');
    }
  }

  Future<void> _joinLeaderboard(String code) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      await _apiService.joinLeaderboard(code);
      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Successfully joined leaderboard!')),
      );
      navigator.pop(true);
    } catch (e) {
      _showError('Failed to join leaderboard: $e');
    } finally {
      if(mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showError(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: colorScheme.onError)),
        backgroundColor: colorScheme.error,
      ),
    );
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Join Leaderboard')),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  onDetect: (capture) => _processJoinLink(capture.barcodes.first.rawValue),
                ),
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.onSurface, width: 2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text('Or paste the join link below:'),
                const SizedBox(height: 8),
                TextField(
                  controller: _linkController,
                  decoration: const InputDecoration(
                    labelText: 'Join Link',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _isProcessing ? null : () => _processJoinLink(_linkController.text),
                  child: const Text('Join with Link'),
                ),
              ],
            ),
          ),
          if (_isProcessing)
            Container(
              color: colorScheme.scrim.withValues(alpha:0.5),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}