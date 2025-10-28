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
  // No longer need instance for static method: final Uuid _uuid = const Uuid();

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
    // --- FIX: Call static method directly on the class ---
    else if (Uuid.isValidUUID(fromString: trimmedInput)) { // Use validator
      // --- END FIX ---
      inviteCode = trimmedInput; // It's already the code
    }
    // Otherwise, it's invalid
    else {
      _showError('Invalid invite code format.');
      return; // Stop processing
    }

    // If we extracted a valid-looking code, attempt to join
    if (inviteCode != null && inviteCode.isNotEmpty) {
      // Validate UUID format again just to be sure before API call
      // --- FIX: Call static method directly on the class ---
      if (Uuid.isValidUUID(fromString: inviteCode)) {
        // --- END FIX ---
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
    // Use local context variable
    final currentContext = context;
    if (!currentContext.mounted) return;

    final scaffoldMessenger = ScaffoldMessenger.of(currentContext);
    final navigator = Navigator.of(currentContext);

    try {
      await _apiService.joinLeaderboard(code); // API expects just the code string

      // Check mounted after await
      if (!currentContext.mounted) return;

      scaffoldMessenger.showSnackBar(
        const SnackBar(content: Text('Successfully joined leaderboard!'), backgroundColor: Colors.green),
      );
      navigator.pop(true); // Pop and signal success
    } catch (e) {
      print("Error joining leaderboard: $e"); // Log full error
      // Check mounted before showing error
      if (currentContext.mounted) {
        _showError('Failed to join leaderboard: ${e.toString().replaceFirst('Exception: ', '')}');
      }
    } finally {
      // Ensure processing state is reset if still mounted
      if (mounted) { // Use general mounted here
        setState(() => _isProcessing = false);
      }
    }
  }

  // Shows an error message SnackBar
  void _showError(String message) {
    // Use local context variable
    final currentContext = context;
    if (!currentContext.mounted) return;

    final colorScheme = Theme.of(currentContext).colorScheme;
    ScaffoldMessenger.of(currentContext).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: colorScheme.onErrorContainer)),
        backgroundColor: colorScheme.errorContainer,
      ),
    );
    // No longer need delayed state reset here, _joinLeaderboard handles it in finally
    // Future.delayed(const Duration(seconds: 2), () { ... });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Join Leaderboard')),
      body: Stack( // Use Stack to overlay loading indicator
        children: [
          Column(
            children: [
              // --- QR Scanner Section ---
              Expanded(
                child: ClipRRect( // Clip scanner view if needed
                  // borderRadius: BorderRadius.circular(12), // Optional styling
                  child: MobileScanner(
                    // Fit camera feed
                    fit: BoxFit.cover,
                    // Controller recommended for more control (start/stop/torch)
                    // controller: MobileScannerController(facing: CameraFacing.back),
                    onDetect: (capture) {
                      // Process the *first* barcode found
                      final String? codeValue = capture.barcodes.first.rawValue;
                      print("QR Scan detected: $codeValue"); // Log scanned value
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
                        hintText: 'e.g., a1b2c3d4-e5f6...', // Add hint
                      ),
                      // Validate input length/format roughly? UUID has fixed length.
                      // inputFormatters: [LengthLimitingTextInputFormatter(36)], // UUID length
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.group_add),
                      label: const Text('Join with Code'),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 45), // Make button wider
                      ),
                      // Disable button while processing
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
              color: colorScheme.scrim.withOpacity(0.6),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}