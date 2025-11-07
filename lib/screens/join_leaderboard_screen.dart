import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/api_service.dart';
import 'package:uuid/uuid.dart'; // Import Uuid package for validation

class JoinLeaderboardScreen extends StatefulWidget {
  const JoinLeaderboardScreen({super.key});

  @override
  State<JoinLeaderboardScreen> createState() => _JoinLeaderboardScreenState();
}

class _JoinLeaderboardScreenState extends State<JoinLeaderboardScreen> {
  final ApiService _apiService = ApiService();
  final _codeController = TextEditingController(); // Renamed from _linkController
  bool _isProcessing = false;
  // --- ADDED: Scanner Controller ---
  final MobileScannerController _scannerController = MobileScannerController(
    facing: CameraFacing.back,
    torchEnabled: false,
  );
  // --- END ADDED ---

  @override
  void dispose() {
    // --- ADDED: Dispose controller ---
    _scannerController.dispose();
    _codeController.dispose();
    // --- END ADDED ---
    super.dispose();
  }


  // Handles processing input from QR scan or text field
  void _processJoinInput(String? input) {
    if (_isProcessing || input == null || input.isEmpty) return;

    final String trimmedInput = input.trim();
    String? inviteCode;

    // Check if it's the full deep link (likely from QR scan)
    if (trimmedInput.startsWith('drinkleaderboard://join?code=')) {
      try {
        final uri = Uri.parse(trimmedInput);
        inviteCode = uri.queryParameters['code'];
      } catch (e) {
        print("Error parsing deep link URI: $e");
        _showError('Invalid join link format.');
        return; // Stop processing
      }

    }
    // Check if it's potentially just a UUID (likely from manual input)
    else if (Uuid.isValidUUID(fromString: trimmedInput)) { // Use validator
      inviteCode = trimmedInput; // It's already the code
    }
    // Otherwise, it's invalid
    else {
      _showError('Invalid invite code format.');
      return; // Stop processing
    }

    // If we extracted a valid-looking code, attempt to join
    if (inviteCode != null && inviteCode.isNotEmpty) {
      if (Uuid.isValidUUID(fromString: inviteCode)) {
        setState(() => _isProcessing = true);
        _joinLeaderboard(inviteCode);
      } else {
        _showError('Invalid invite code format extracted.');
      }

    } else {
      _showError('Could not extract invite code.');
    }
  }


  // Calls the API with the extracted invite code (UUID string)
  Future<void> _joinLeaderboard(String code) async {
    final currentContext = context;
    if (!currentContext.mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(currentContext);
    final navigator = Navigator.of(currentContext);

    try {
      await _apiService.joinLeaderboard(code);

      if (!currentContext.mounted) return;

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Successfully joined leaderboard!'), backgroundColor: Colors.green),
      );

      // --- FIX: Stop camera BEFORE popping ---
      await _scannerController.stop();
      // --- END FIX ---

      navigator.pop(true); // Pop and signal success
    } catch (e) {
      print("Error joining leaderboard: $e");
      if (currentContext.mounted) {
        _showError('Failed to join leaderboard: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    } finally {
      // Ensure processing state is reset if still mounted
      if (mounted) {
        setState(() => _isProcessing = false);
        // Ensure camera is stopped even if API call fails
        // (though stopping it again if already stopped is fine)
        _scannerController.stop();
      }
    }
  }

  // Shows an error message SnackBar
  void _showError(String message) {
    final currentContext = context;
    if (!currentContext.mounted) return;

    final colorScheme = Theme.of(currentContext).colorScheme;
    ScaffoldMessenger.of(currentContext).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: colorScheme.onErrorContainer)),
        backgroundColor: colorScheme.errorContainer,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Join Leaderboard')),
      body: Stack(
        children: [
          Column(
            children: [
              // --- QR Scanner Section ---
              Expanded(
                child: ClipRRect(
                  child: MobileScanner(
                    // --- ADDED: Pass controller ---
                    controller: _scannerController,
                    // --- END ADDED ---
                    fit: BoxFit.cover,
                    onDetect: (capture) {
                      final String? codeValue = capture.barcodes.first.rawValue;
                      print("QR Scan detected: $codeValue");
                      _processJoinInput(codeValue);
                    },

                  ),
                ),
              ),
              // --- Manual Input Section ---
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Text('Scan QR or paste invite code below:', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _codeController,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'Invite Code',
                        border: OutlineInputBorder(),
                        hintText: 'e.g., a1b2c3d4-e5f6...',
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.group_add),
                      label: const Text('Join with Code'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      onPressed: _isProcessing ? null : () => _processJoinInput(_codeController.text),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // --- Loading Overlay ---
          if (_isProcessing)
            Container(
              color: colorScheme.scrim.withValues(alpha:0.6),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}