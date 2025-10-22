import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart'; // <-- NEW IMPORT
import 'package:flutter/foundation.dart' show kIsWeb; // <-- NEW IMPORT

class AuthService {
  final String _baseUrl = "https://api.oscarkohn.com";
  final _storage = const FlutterSecureStorage();

  // --- NEW: Biometric Services ---
  final LocalAuthentication _localAuth = LocalAuthentication();
  static const String _biometricsEnabledKey = 'biometrics_enabled';

  /// Checks if the device has biometric hardware (e.g., fingerprint sensor)
  /// and if the user has enrolled.
  /// On Web, this will always return false.
  Future<bool> isBiometricsSupported() async {
    // Don't even try on web
    if (kIsWeb) {
      return false;
    }

    try {
      final bool canCheck = await _localAuth.canCheckBiometrics;
      final bool isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (e) {
      return false;
    }
  }

  /// Prompts the user to authenticate with their fingerprint/face.
  Future<bool> authenticateWithBiometrics(String reason) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true, // Keep prompt open until success/fail
          biometricOnly: true, // Only allow fingerprint/face, not PIN
        ),
      );
    } catch (e) {
      return false;
    }
  }

  /// Checks if the user has *enabled* the biometric login feature.
  Future<bool> isBiometricsEnabled() async {
    return await _storage.read(key: _biometricsEnabledKey) == 'true';
  }

  /// Saves the user's preference for using biometric login.
  Future<void> setBiometricsEnabled(bool isEnabled) async {
    await _storage.write(key: _biometricsEnabledKey, value: isEnabled.toString());
  }

  // --- Existing Auth Methods ---

  Future<void> register(String username, String password) async {
    // ... (no changes)
    final response = await http.post(
      Uri.parse('$_baseUrl/users/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to register user.');
    }
  }

  Future<void> login(String username, String password) async {
    // ... (no changes)
    final response = await http.post(
      Uri.parse('$_baseUrl/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': username, 'password': password},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      await _storage.write(key: 'auth_token', value: data['access_token']);
      await _storage.write(key: 'refresh_token', value: data['refresh_token']);
      await _storage.write(key: 'username', value: username);
    } else {
      throw Exception('Invalid credentials. Please try again.');
    }
  }

  Future<void> logout(String refreshToken) async {
    // ... (no changes)
    try {
      await http.post(
        Uri.parse('$_baseUrl/logout'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );
    } catch (e) {
      //"Failed to revoke token on server: $e");
    }
  }

  Future<String?> verifyTokenAndGetUser() async {
    // ... (no changes)
    String? token = await getToken();
    if (token == null) return null;

    final response = await http.get(
      Uri.parse('$_baseUrl/users/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final username = data['username'];
      await _storage.write(key: 'username', value: username);
      return username;
    } else {
      return null;
    }
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<String?> getRefreshToken() async {
    return await _storage.read(key: 'refresh_token');
  }

  Future<String?> getUsername() async {
    return await _storage.read(key: 'username');
  }

  Future<void> deleteLocalTokens() async {
    // ... (no changes)
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'refresh_token');
    await _storage.delete(key: 'username');
  }
}