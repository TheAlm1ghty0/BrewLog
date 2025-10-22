import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:awesome_dialog/awesome_dialog.dart'; // <-- NEW IMPORT
import '../services/auth_service.dart';
import '../providers/auth_provider.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  // --- NEW: Biometric helper ---
  Future<void> _tryBiometricLogin() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final colorScheme = Theme.of(context).colorScheme;

    if (!authProvider.isBiometricsEnabled) {
      // This should not happen if called from initState, but good to check
      return;
    }

    setState(() => _isLoading = true);

    final bool didAuthenticate = await _authService.authenticateWithBiometrics(
      'Please scan your fingerprint to log in.',
    );

    if (!didAuthenticate) {
      if (mounted) setState(() => _isLoading = false);
      return; // User cancelled
    }

    // Biometric scan was successful, now try to get a new token
    try {
      final username = await _authService.verifyTokenAndGetUser();
      if (username != null && mounted) {
        authProvider.login(username); // This will log the user in
      } else if (mounted) {
        // This can happen if the refresh token is also expired
        _showError('Your session has expired. Please log in with your password.');
        await authProvider.setBiometricsEnabled(false); // Disable biometrics
      }
    } catch (e) {
      if (mounted) {
        _showError('An error occurred. Please log in with your password.');
        await authProvider.setBiometricsEnabled(false); // Disable biometrics
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- NEW: Ask to enable biometrics ---
  void _showEnableBiometricsDialog() {
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.isBiometricsSupported) {
      return; // Don't ask if not supported
    }

    AwesomeDialog(
      context: context,
      dialogType: DialogType.noHeader,
      animType: AnimType.bottomSlide,
      title: 'Enable Biometric Login?',
      desc: 'Would you like to use your fingerprint to log in next time?',
      btnCancelOnPress: () {},
      btnOkText: 'Enable',
      btnOkOnPress: () async {
        final bool didAuth = await _authService.authenticateWithBiometrics(
          'Please scan your fingerprint to confirm.',
        );
        if (didAuth) {
          await authProvider.setBiometricsEnabled(true);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Biometric Login Enabled!')),
            );
          }
        }
      },
    ).show();
  }

  // --- UPDATED: Password Login ---
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final username = _usernameController.text;
      await _authService.login(username, _passwordController.text);
      if (mounted) {
        Provider.of<AuthProvider>(context, listen: false).login(username);
        // --- NEW: Ask to enable biometrics ---
        _showEnableBiometricsDialog();
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // --- NEW: Error helper ---
  void _showError(String message) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: TextStyle(color: colorScheme.onError),
        ),
        backgroundColor: colorScheme.error,
      ),
    );
  }

  // --- NEW: initState to check for auto-login ---
  @override
  void initState() {
    super.initState();
    // Use WidgetsBinding to wait for the first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = context.read<AuthProvider>();
      // We check for biometric support *and* if the user has enabled it
      if (authProvider.isBiometricsSupported && authProvider.isBiometricsEnabled) {
        _tryBiometricLogin();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // We use Consumer here to get the *latest* biometric support status
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('Login')),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
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
                    ),
                    obscureText: true,
                    validator: (value) =>
                    value!.isEmpty ? 'Please enter a password' : null,
                  ),
                  const SizedBox(height: 24),
                  if (_isLoading)
                    const CircularProgressIndicator()
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: _login,
                          child: const Text('Login'),
                        ),
                        const SizedBox(height: 8),

                        // --- NEW: Biometric Button (PWA-SAFE) ---
                        // This button will only be built if `isBiometricsSupported`
                        // is true, making it safe for web.
                        if (auth.isBiometricsSupported)
                          OutlinedButton.icon(
                            icon: const Icon(Icons.fingerprint),
                            onPressed: _tryBiometricLogin,
                            label: const Text('Login with Biometrics'),
                          ),

                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) =>
                                    RegisterScreen(authService: _authService),
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
        );
      },
    );
  }
}