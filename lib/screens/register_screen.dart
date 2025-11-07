import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  final AuthService authService;
  const RegisterScreen({super.key, required this.authService});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  // --- NEW: Confirm Password Controller ---
  final _confirmPasswordController = TextEditingController();
  // --- END NEW ---
  bool _isLoading = false;

  // --- NEW: Error Message State ---
  String? _errorMessage;
  // --- END NEW ---

  @override
  void initState() {
    super.initState();
    // --- NEW: Clear error when user starts typing ---
    _usernameController.addListener(() {
      if (_errorMessage != null) setState(() => _errorMessage = null);
    });
    _passwordController.addListener(() {
      if (_errorMessage != null) setState(() => _errorMessage = null);
    });
    _confirmPasswordController.addListener(() {
      if (_errorMessage != null) setState(() => _errorMessage = null);
    });
    // --- END NEW ---
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose(); // Dispose new controller
    super.dispose();
  }

  Future<void> _register() async {
    // --- NEW: Clear previous error ---
    setState(() {
      _errorMessage = null;
    });
    // --- END NEW ---

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // --- NEW: Check if passwords match ---
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match.';
      });
      return;
    }
    // --- END NEW ---

    setState(() {
      _isLoading = true;
    });

    final String username = _usernameController.text;
    final String password = _passwordController.text;

    try {
      await widget.authService.register(username, password);
      // --- MODIFICATION: Don't auto-login, just pop ---
      // await widget.authService.login(username, password); // User will log in themselves

      if (mounted) {
        // --- MODIFICATION: Show success snackbar and pop ---
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Registration successful! Please log in.'),
            backgroundColor: Colors.green,
          ),
        );
        // Provider.of<AuthProvider>(context, listen: false).login(username); // Don't log in
        Navigator.of(context).pop(); // Go back to login screen
        // --- END MODIFICATION ---
      }
    } catch (e) {
      if (mounted) {
        // --- MODIFICATION: Set error message state ---
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
        // --- END MODIFICATION ---
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- NEW: Get screen height ---
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    // --- END NEW ---

    return Scaffold(
      body: Center( // Center the content
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0), // Match login padding
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- MODIFIED: Use screen height percentage ---
                SizedBox(
                  // Use 15% of the screen height for the logo
                  height: screenHeight * 0.20,
                  // Constrain width to be a square
                  width: screenWidth * 0.20,
                  child: ClipRect(
                    child: FittedBox(
                      fit: BoxFit.contain, // This will "zoom" and crop the image
                      alignment: Alignment.center,
                      child: Image.asset(
                        'assets/inApp_logo.png', // Path to your logo image
                        errorBuilder: (context, error, stackTrace) =>
                            Icon(Icons.local_drink, size: screenHeight * 0.20), // Placeholder
                      ),
                    ),
                  ),
                ),
                // --- END MODIFIED ---
                const SizedBox(height: 16),
                // --- MODIFIED: Use screen height percentage ---
                SizedBox(
                  // Use 5% of the screen height for the name
                  height: screenHeight * 0.10,
                  child: Image.asset(
                    'assets/text_only.png', // Path to your app name image
                    fit: BoxFit.contain,
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
                ),
                // --- END MODIFIED ---
                SizedBox(height: screenHeight * 0.04), // 4% of screen height
                // --- END ---

                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a username';
                    }
                    return null;
                  },
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a password';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters long.';
                    }
                    return null;
                  },
                ),
                // --- NEW: Confirm Password Field ---
                const SizedBox(height: 16),
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_reset_outlined),
                  ),

                  obscureText: true,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                // --- END NEW ---

                // --- MODIFICATION: Standardized Error Message Placeholder ---
                Visibility(
                  visible: _errorMessage != null,
                  maintainState: true,
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

                _isLoading
                    ? const Padding( // Match login screen's loading state
                  padding: EdgeInsets.symmetric(vertical: 20.0),
                  child: CircularProgressIndicator(),
                )
                    : Column( // Match login screen's button layout
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: _register,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Register'), // Button text changed
                    ),
                    // --- NEW: Placeholder for Biometrics Button ---
                    const SizedBox(height: 12),
                    Visibility(
                      visible: false, // Not visible on register screen
                      maintainState: true,
                      maintainSize: true,
                      maintainAnimation: true,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Login with Biometrics'),
                        onPressed: null, // Disabled
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    // --- END NEW ---
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(); // Go back to login
                      },
                      child: const Text('Already have an account? Login'), // Text changed
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