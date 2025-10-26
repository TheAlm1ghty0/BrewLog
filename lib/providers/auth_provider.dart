import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:local_auth/local_auth.dart'; // Import local_auth
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences

class AuthProvider with ChangeNotifier {
  // Pass LocalAuthentication instance to AuthService
  final AuthService _authService = AuthService(LocalAuthentication());
  bool _isAuthenticated = false;
  String? _username;
  bool _isBiometricsGloballyEnabled = false; // Add state for biometric preference

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;
  bool get isBiometricsGloballyEnabled => _isBiometricsGloballyEnabled; // Getter

  AuthProvider() {
    // Load biometric preference on initialization
    _loadBiometricPreference();
  }

  Future<void> _loadBiometricPreference() async {
    _isBiometricsGloballyEnabled = await _authService.isBiometricsEnabled();
    notifyListeners(); // Notify after loading initial preference
  }

  Future<void> checkAuth() async {
    final validatedUsername = await _authService.verifyTokenAndGetUser();

    if (validatedUsername != null) {
      _isAuthenticated = true;
      _username = validatedUsername;
      await _loadBiometricPreference(); // Ensure preference is loaded on auth check
    } else {
      // Don't call full logout here, just clear provider state
      _isAuthenticated = false;
      _username = null;
      _isBiometricsGloballyEnabled = false; // Reset if auth check fails
      // We don't necessarily need to delete local tokens here,
      // as they might be needed for biometric login on next launch.
      // Let the login screen handle attempting biometric login if enabled.
    }
    notifyListeners();
  }


  void login(String username) {
    _isAuthenticated = true;
    _username = username;
    // Load preference *after* successful login if needed, or rely on checkAuth post-restart
    _loadBiometricPreference(); // Ensure state reflects stored pref after login
    notifyListeners();
  }

  // Make logout async to handle API call and token deletion
  Future<void> logout() async {
    await _authService.logout(); // Calls AuthService.logout() which ONLY deletes access token now
    _isAuthenticated = false;
    _username = null; // Clear username in provider state
    // _isBiometricsGloballyEnabled = false; // REMOVED: Do NOT reset preference on manual logout
    notifyListeners();
  }


  // Method to update biometric preference
  Future<void> setBiometricPreference(bool enabled) async {
    if (enabled) {
      // Check if device actually supports it before enabling
      bool supported = await _authService.isDeviceSupported();
      bool canCheck = await _authService.canCheckBiometrics();
      if (supported && canCheck) {
        await _authService.enableBiometrics();
        _isBiometricsGloballyEnabled = true;
      } else {
        // Optionally show an error if trying to enable on unsupported device
        print("Attempted to enable biometrics on unsupported device.");
        _isBiometricsGloballyEnabled = false; // Ensure state remains false
        // Keep the stored preference false as well
        await _authService.disableBiometrics();

      }
    } else {
      await _authService.disableBiometrics();
      _isBiometricsGloballyEnabled = false;
    }
    notifyListeners();
  }


  // Expose AuthService if needed by other parts, like SettingsScreen
  // (Be cautious about exposing the entire service)
  AuthService get authService => _authService;
}