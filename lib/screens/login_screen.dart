import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart'; // Import for biometrics
import '../services/auth_service.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';
import 'package:awesome_dialog/awesome_dialog.dart'; // Import AwesomeDialog

class LoginScreen extends StatefulWidget {
  // Removed authProvider from constructor, as it's accessed via Provider
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  // Access AuthService via AuthProvider or create instance carefully
  late AuthService _authService;
  bool _isLoading = false;
  bool _deviceSupportsBiometrics = false;
  bool _canCheckBiometrics = false;
  bool _attemptedAutoBiometrics = false; // Flag to prevent multiple auto-prompts

  // --- FIX: Define _errorMessage ---
  String? _errorMessage;
  // --- END FIX ---

  @override
  void initState() {
    super.initState();
    // Use listen: false in initState
    _authService = Provider.of<AuthProvider>(context, listen: false).authService;
    // --- ADDED LOGGING on Init ---
    _logStoredCredentials();
    // --- END LOGGING ---
    _checkBiometricsAndAttemptAutoLogin();

    // --- NEW: Clear error when user starts typing ---
    _usernameController.addListener(() {
      if (_errorMessage != null) setState(() => _errorMessage = null);
    });
    _passwordController.addListener(() {
      if (_errorMessage != null) setState(() => _errorMessage = null);
    });
    // --- END NEW ---
  }

  // --- ADDED LOGGING FUNCTION ---
  Future<void> _logStoredCredentials() async {
    print("LoginScreen initState: Checking stored credentials...");
    final storedUsername = await _authService.getUsername();
    final storedRefreshToken = await _authService.getRefreshToken();
    final biometricsPref = await _authService.isBiometricsEnabled();
    print("LoginScreen initState: Stored Username: $storedUsername");
    print("LoginScreen initState: Stored Refresh Token Exists: ${storedRefreshToken != null}");
    print("LoginScreen initState: Biometrics Enabled Preference: $biometricsPref");
  }
  // --- END LOGGING FUNCTION ---

  Future<void> _checkBiometricsAndAttemptAutoLogin() async {
    // Check support first
    bool supported = await _authService.isDeviceSupported();
    bool canCheck = false;
    if (supported) {
      canCheck = await _authService.canCheckBiometrics();
    }

    // Use local variable for context check
    final currentContext = context;
    // Check mounted status *before* async gaps and *after* async gaps where context is used
    if (!currentContext.mounted) return;

    // Update state only if still mounted
    setState(() {
      _deviceSupportsBiometrics = supported;
      _canCheckBiometrics = canCheck;
    });
    print("Biometrics Check: Supported=$supported, CanCheck=$canCheck"); // LOGGING


    // Only attempt auto-login if supported, enabled, and not already attempted
    bool enabled = await _authService.isBiometricsEnabled();
    print("Biometrics Check: Enabled=$enabled, AttemptedAuto=$_attemptedAutoBiometrics"); // LOGGING

    // Check mounted again before potentially showing loading/dialog
    if (!currentContext.mounted) return;

    if (supported && canCheck && enabled && !_attemptedAutoBiometrics) {
      print("Attempting automatic biometric login..."); // LOGGING
      setState(() {
        _attemptedAutoBiometrics = true; // Mark as attempted
        _isLoading = true; // Show loading indicator during biometric prompt
      });
      await _loginWithBiometrics(isAutoAttempt: true);

      // Check mounted again before stopping loading
      // isLoading might have been set to false within _loginWithBiometrics if auto-refresh succeeded
      if (currentContext.mounted && _isLoading) {
        print("Automatic biometric login finished or failed (needed prompt?), stopping loading."); // LOGGING
        setState(() => _isLoading = false);
      }
    }
  }


  Future<void> _login() async {
    // Use local variable for context checks
    final currentContext = context;
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Check mounted before showing loading
    if (!currentContext.mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null; // Clear previous error
    });

    try {
      final username = _usernameController.text;
      print("Attempting password login for user: $username"); // LOGGING
      await _authService.login(username, _passwordController.text);
      print("Password login successful via AuthService."); // LOGGING

      // Check mounted before accessing Provider or checking biometrics
      if (!currentContext.mounted) return;

      final authProvider = Provider.of<AuthProvider>(currentContext, listen: false);

      // --- FIX: Trigger navigation FIRST ---
      authProvider.login(username); // Notify provider - THIS TRIGGERS NAVIGATION
      print("AuthProvider notified of login. Navigation should occur."); // LOGGING
      // --- END FIX ---

      // Check if biometrics are supported but not yet enabled, then ask
      bool enabled = await _authService.isBiometricsEnabled();
      print("Checking if should show enable biometrics dialog: Supported=$_deviceSupportsBiometrics, CanCheck=$_canCheckBiometrics, Enabled=$enabled"); // LOGGING

      // Check mounted again before scheduling the dialog
      if (!currentContext.mounted) return;

      if (_deviceSupportsBiometrics && _canCheckBiometrics && !enabled) {
        // --- FIX: Schedule dialog show AFTER frame build (and navigation) ---
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Check mounted *again* inside the callback, as state might change
          if (mounted) { // Use the general 'mounted' here as context might be different post-frame
            // Use the Navigator's context which should be valid after navigation
            // Check if Navigator exists above this context first
            final navigatorState = Navigator.maybeOf(context);
            if (navigatorState != null && navigatorState.context.mounted) {
              _showEnableBiometricsDialog(navigatorState.context); // Pass the valid context
            } else {
              print("Error: Navigator context not found or not mounted when trying to show dialog post-frame.");
            }

          } else {
            print("Error: Widget not mounted when trying to show dialog post-frame.");
          }
        });
        // --- END FIX ---
      }
    } catch (e) {
      print("Password login failed: $e"); // LOGGING
      // Check mounted before showing error
      // --- FIX: Set error message state ---
      if (currentContext.mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
      // --- END FIX ---
    } finally {
      // Check mounted before stopping loading
      if (currentContext.mounted) setState(() => _isLoading = false);
    }
  }


  // --- MODIFIED: Try silent refresh first on auto-attempt ---
  Future<void> _loginWithBiometrics({bool isAutoAttempt = false}) async {
    final currentContext = context; // Capture context
    print("Executing _loginWithBiometrics (isAutoAttempt: $isAutoAttempt)");

    if (!currentContext.mounted) return;
    // Don't set loading true for auto-attempt here, _checkBiometrics... handles it
    if (!isAutoAttempt) {
      setState(() {
        _isLoading = true;
        _errorMessage = null; // Clear previous error
      });
    }

    final username = await _authService.getUsername();
    final refreshTokenExists = (await _authService.getRefreshToken()) != null;
    print("Stored username: $username, Refresh token exists: $refreshTokenExists");

    if (!currentContext.mounted) return;

    if (username != null && refreshTokenExists) {
      // --- NEW: Direct Refresh Logic for Auto Attempt ---
      if (isAutoAttempt) {
        print("Auto Attempt: Trying silent refresh first...");
        try {
          final newAccessToken = await _authService.refreshAccessToken();
          print("Auto Attempt: refreshAccessToken returned: ${newAccessToken != null ? 'Success' : 'Failed'}");

          if (!currentContext.mounted) return;

          if (newAccessToken != null) {
            // Silent refresh succeeded! Log in without prompt.
            print("Auto Attempt: Silent refresh successful. Logging in user $username.");
            Provider.of<AuthProvider>(currentContext, listen: false).login(username);
            // No need to set loading false here, _checkBiometrics... handles it
            return; // EXIT EARLY - SUCCESS
          } else {
            // Silent refresh failed (e.g., refresh token expired)
            print("Auto Attempt: Silent refresh failed. Proceeding to show biometric prompt.");
            // Fall through to show the biometric prompt below
          }
        } on SessionExpiredException catch (_) {
          print("Auto Attempt: SessionExpiredException during silent refresh. Proceeding to show biometric prompt.");
          // Fall through
        } catch (e) {
          print("Auto Attempt: Error during silent refresh: $e. Proceeding to show biometric prompt.");
          // Fall through
        }
      }
      // --- END NEW LOGIC ---

      // --- Biometric Prompt (Manual Button OR Fallback for failed Auto Refresh) ---
      print("Showing biometric prompt (manual button press or fallback)...");
      bool didAuthenticate = false;
      try {
        didAuthenticate = await _authService.authenticateWithBiometrics(
            'Please authenticate to log in.');
      } catch (e) {
        print("Error during _authService.authenticateWithBiometrics call: $e");
        // Handle specific errors if needed, otherwise fall through
      }

      print("authenticateWithBiometrics returned: $didAuthenticate");

      if (!currentContext.mounted) return;

      if (didAuthenticate) {
        print("Fingerprint scan successful. Refreshing session...");
        try {
          // Always refresh after successful fingerprint, even if auto-refresh failed
          final newAccessToken = await _authService.refreshAccessToken();
          print("Fingerprint Login: refreshAccessToken returned: ${newAccessToken != null ? 'Success' : 'Failed'}");

          if (!currentContext.mounted) return;

          if (newAccessToken != null) {
            print("Fingerprint Login: Refresh successful. Logging in user $username.");
            Provider.of<AuthProvider>(currentContext, listen: false).login(username);
          } else {
            print("Fingerprint Login: Refresh failed after successful scan.");
            if (currentContext.mounted) _showError("Biometric login failed. Please use password.");
          }
        } on SessionExpiredException catch (_) {
          print("Fingerprint Login: SessionExpiredException during refresh after scan.");
          if (currentContext.mounted) _showError("Biometric login failed (session expired). Please use password.");
        } catch (e) {
          print("Fingerprint Login: Error during refresh after scan: $e");
          if (currentContext.mounted) _showError("Biometric login failed. Please use password.");
        }
      } else if (!isAutoAttempt) {
        // Only show 'failed' snackbar if it was a manual button press
        print("Fingerprint scan failed or was cancelled by user (manual attempt).");
        _showError('Biometric authentication failed.');
      }
      // --- END Biometric Prompt ---

    } else {
      // No username/refresh token found, even if biometrics succeeded somehow
      print("Biometric check: No local credentials found.");
      if (currentContext.mounted) {
        _showError('Please log in with your password first to enable biometric login.');
        await _authService.disableBiometrics();
        // Check mounted again before Provider call
        if(currentContext.mounted){
          Provider.of<AuthProvider>(currentContext, listen: false).setBiometricPreference(false);
        }
      }
    }

    // Stop loading indicator only if it wasn't an auto-attempt that succeeded silently
    // Or if it was an auto-attempt that failed and fell through
    if (currentContext.mounted && _isLoading) {
      setState(() => _isLoading = false);
    }
  }
  // --- END MODIFICATION ---


  // --- Updated: Takes context parameter ---
  void _showEnableBiometricsDialog(BuildContext dialogContext) {
    // --- End Update ---
    print("Showing Enable Biometrics Dialog..."); // LOGGING
    final colorScheme = Theme.of(dialogContext).colorScheme; // Use passed context
    final authProvider = Provider.of<AuthProvider>(dialogContext, listen: false); // Use passed context
    final scaffoldMessenger = ScaffoldMessenger.of(dialogContext); // Use passed context


    AwesomeDialog(
      context: dialogContext, // Use passed context
      dialogType: DialogType.infoReverse,
      animType: AnimType.bottomSlide,
      title: 'Enable Biometric Login',
      desc: 'Would you like to use your fingerprint or face to log in next time?',
      btnCancelText: 'Not Now',
      btnCancelOnPress: () {
        print("Enable Biometrics Dialog: 'Not Now' pressed."); // LOGGING
        // No need to manually dismiss, AwesomeDialog handles it
      },
      btnOkText: 'Enable',
      btnOkColor: colorScheme.primary,
      btnOkOnPress: () async {
        print("Enable Biometrics Dialog: 'Enable' pressed."); // LOGGING
        // Use local context variable inside async gap if needed, but dialogContext should be fine here
        print("Enable Biometrics Dialog: Calling authenticateWithBiometrics for confirmation..."); // LOGGING
        bool didAuthenticate = await _authService.authenticateWithBiometrics(
            'Confirm fingerprint to enable biometric login.');
        print("Enable Biometrics Dialog: Confirmation authenticate returned: $didAuthenticate"); // LOGGING

        // Check if the dialog's context is still valid *before* updating state/showing snackbar
        if (!dialogContext.mounted) return;

        if (didAuthenticate) {
          print("Enable Biometrics Dialog: Confirmation success. Enabling preference..."); // LOGGING
          await authProvider.setBiometricPreference(true);
          // Check mounted again before showing snackbar
          if (dialogContext.mounted) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Biometric login enabled!')),
            );
          }
        } else {
          print("Enable Biometrics Dialog: Confirmation failed."); // LOGGING
          if (dialogContext.mounted) {
            scaffoldMessenger.showSnackBar(
              const SnackBar(content: Text('Authentication failed. Biometrics not enabled.')),
            );
          }
        }
        // No need to manually dismiss dialog here, AwesomeDialog handles it on button press
      },
    ).show();
  }

  void _showError(String message) {
    // Use local context variable
    final currentContext = context;
    if (!currentContext.mounted) return;
    // --- FIX: Set error message state ---
    setState(() {
      _errorMessage = message;
    });
    // --- END FIX ---
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // --- REMOVED AppBar ---
      // appBar: AppBar(title: const Text('Login')),
      body: Center( // Center the content vertically and horizontally
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch, // Make children stretch
              children: [
                // --- MODIFIED: App Logo with FittedBox ---
                SizedBox(
                  height: 240, // Desired display height for the logo
                  child: ClipRect(
                    child: FittedBox(
                      fit: BoxFit.cover, // This will "zoom" and crop the image to fill the 120px height
                      alignment: Alignment.center,
                      child: Image.asset(
                        'assets/logo_only.png', // Path to your logo image
                        // No fit property here, let FittedBox handle it
                        errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.local_drink, size: 120), // Placeholder
                      ),
                    ),
                  ),
                ),
                // --- END MODIFIED ---
                const SizedBox(height: 16),
                Image.asset(
                  'assets/text_only.png', // Path to your app name image
                  height: 130, // Adjust height as needed
                  errorBuilder: (context, error, stackTrace) =>
                      Text(
                        'BrewLog',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ), // Placeholder
                ),
                const SizedBox(height: 48),
                // --- END NEW ---

                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) =>
                  value!.isEmpty ? 'Please enter a username' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                  obscureText: true,
                  validator: (value) =>
                  value!.isEmpty ? 'Please enter a password' : null,
                ),
                // --- MODIFICATION: Added placeholders ---
                const SizedBox(height: 16),
                Visibility(
                  visible: false, // Not visible on login screen
                  maintainState: true,
                  maintainSize: true, // Takes up space
                  maintainAnimation: true,
                  child: TextFormField(
                    readOnly: true, // Not interactive
                    decoration: const InputDecoration(
                      labelText: 'Confirm Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_reset_outlined),
                    ),
                  ),
                ),
                Visibility(
                  visible: _errorMessage != null, // Show if error exists
                  maintainState: true, // Keep space even if null
                  maintainSize: true,
                  maintainAnimation: true,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      _errorMessage ?? " ", // Use space to maintain height
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                // --- END MODIFICATION ---
                const SizedBox(height: 24),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0), // Add padding around spinner
                    child: CircularProgressIndicator(),
                  )
                else
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _login,
                        child: const Text('Login'),
                      ),
                      const SizedBox(height: 12),
                      // --- Biometric Button ---
                      // Only show if supported AND check passes (e.g., fingerprint enrolled)
                      if (_deviceSupportsBiometrics && _canCheckBiometrics)
                        OutlinedButton.icon(
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('Login with Biometrics'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(color: Theme.of(context).colorScheme.outline),
                          ),
                          onPressed: () => _loginWithBiometrics(),
                        ),

                      const SizedBox(height: 24),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              // Ensure AuthService instance is passed correctly
                              builder: (context) => RegisterScreen(authService: _authService),
                            ),
                          );
                        },
                        child: const Text('Don\'t have an account? Register'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}