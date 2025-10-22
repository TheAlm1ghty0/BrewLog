import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  bool _isAuthenticated = false;
  String? _username;

  // --- NEW BIOMETRIC STATE ---
  /// Does the device hardware support biometrics?
  bool _isBiometricsSupported = false;
  /// Has the user *enabled* biometrics in the app?
  bool _isBiometricsEnabled = false;

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;
  /// Use this to show/hide the "Enable Biometric Login" option.
  bool get isBiometricsSupported => _isBiometricsSupported;
  /// Use this to know if you should *try* to log in with biometrics.
  bool get isBiometricsEnabled => _isBiometricsEnabled;

  /// Checks for a valid token AND loads biometric status.
  Future<void> checkAuth() async {
    final validatedUsername = await _authService.verifyTokenAndGetUser();

    if (validatedUsername != null) {
      _isAuthenticated = true;
      _username = validatedUsername;

      // --- NEW: Check biometric status on auth ---
      _isBiometricsSupported = await _authService.isBiometricsSupported();
      _isBiometricsEnabled = await _authService.isBiometricsEnabled();

    } else {
      await _authService.deleteLocalTokens();
      _isAuthenticated = false;
      _username = null;

      // --- NEW: Clear biometric status on logout ---
      _isBiometricsSupported = false;
      _isBiometricsEnabled = false;
    }
    notifyListeners();
  }

  /// Called after a successful username/password login.
  void login(String username) {
    _isAuthenticated = true;
    _username = username;

    // --- NEW: Check biometric support on login ---
    _authService.isBiometricsSupported().then((isSupported) {
      _isBiometricsSupported = isSupported;
      notifyListeners();
    });

    notifyListeners();
  }

  // --- NEW: Method to enable/disable biometrics ---
  /// Call this from your settings screen or a popup after login.
  Future<void> setBiometricsEnabled(bool isEnabled) async {
    await _authService.setBiometricsEnabled(isEnabled);
    _isBiometricsEnabled = isEnabled;
    notifyListeners();
  }

  /// Logs the user out from the server and clears all local state.
  Future<void> logout() async {
    final refreshToken = await _authService.getRefreshToken();
    if (refreshToken != null) {
      await _authService.logout(refreshToken); // Call API logout
    }
    await _authService.deleteLocalTokens(); // Clear local tokens

    // --- NEW: Clear all state on logout ---
    _isAuthenticated = false;
    _username = null;
    _isBiometricsSupported = false;
    _isBiometricsEnabled = false;
    // Also clear the preference in storage
    await _authService.setBiometricsEnabled(false);

    notifyListeners();
  }
}