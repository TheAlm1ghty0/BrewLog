import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart'; // Import for biometrics
import 'package:flutter/foundation.dart'; // For kIsWeb
import 'package:shared_preferences/shared_preferences.dart'; // For biometric preference

// Define SessionExpiredException here or import if defined elsewhere
class SessionExpiredException implements Exception {
  final String message = "Your session has expired. Please log in again.";
  SessionExpiredException();
}

class AuthService {
  final String _baseUrl = "https://api.oscarkohn.com";
  final _storage = const FlutterSecureStorage();
  final LocalAuthentication? _localAuth; // Make nullable for web safety

  // Constructor now accepts LocalAuthentication
  AuthService(this._localAuth);

  // --- Registration & Login ---
  Future<void> register(String username, String password) async {
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
    final response = await http.post(
      Uri.parse('$_baseUrl/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'username': username, 'password': password},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final accessToken = data['access_token'];
      final refreshToken = data['refresh_token'];

      await _storage.write(key: 'auth_token', value: accessToken);
      print("AuthService login: Wrote access token."); // LOGGING
      await _storage.write(key: 'refresh_token', value: refreshToken);
      print("AuthService login: Wrote refresh token."); // LOGGING
      await _storage.write(key: 'username', value: username);
      print("AuthService login: Wrote username: $username"); // LOGGING

    } else {
      throw Exception('Invalid credentials. Please try again.');
    }
  }

  // --- Token Management ---
  // MODIFIED: Simplified verifyTokenAndGetUser
  Future<String?> verifyTokenAndGetUser() async {
    String? token = await getToken();
    if (token == null) {
      print("verifyTokenAndGetUser: No access token found locally.");
      return null;
    }

    print("verifyTokenAndGetUser: Verifying token with /users/me");
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
      // Refresh username in storage just in case it changed via profile update
      await _storage.write(key: 'username', value: username);
      print("verifyTokenAndGetUser: Token verified for user $username");
      return username;
    } else {
      // If /users/me fails (e.g., 401), the token is invalid.
      // DO NOT attempt refresh here. Let the interceptor handle it during actual API calls.
      print("verifyTokenAndGetUser: Token verification failed (${response.statusCode}).");
      // Optionally clean up if definitely invalid
      // if (response.statusCode == 401) await _deleteLocalTokens();
      return null;
    }
  }
  // --- END MODIFICATION ---


  Future<String?> getToken() async {
    // print("AuthService getToken: Reading access token..."); // Optional: Log reads too
    return await _storage.read(key: 'auth_token');
  }

  Future<String?> getRefreshToken() async {
    // print("AuthService getRefreshToken: Reading refresh token..."); // Optional
    return await _storage.read(key: 'refresh_token');
  }

  Future<String?> getUsername() async {
    // print("AuthService getUsername: Reading username..."); // Optional
    return await _storage.read(key: 'username');
  }

  // --- MODIFIED: Only delete access token ---
  Future<void> _deleteLocalTokens() async {
    await _storage.delete(key: 'auth_token'); // Only delete access token
    // Keep refresh_token and username for next login/biometric attempt
    // await _storage.delete(key: 'refresh_token');
    // await _storage.delete(key: 'username');
    print("_deleteLocalTokens: Deleted only the access token.");
  }
  // --- END MODIFICATION ---

  // --- Refresh Token Logic ---
  Future<String?> refreshAccessToken() async {
    final refreshToken = await getRefreshToken();
    if (refreshToken == null) {
      print("refreshAccessToken: No refresh token found.");
      // Ensure local tokens are cleared if refresh token is missing
      await _deleteLocalTokens(); // This now only deletes access token
      return null; // Can't refresh without a refresh token
    }

    print("refreshAccessToken: Attempting to refresh using token: ${refreshToken.substring(0, 10)}..."); // Log truncated token

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/token/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final newAccessToken = data['access_token'];
        await _storage.write(key: 'auth_token', value: newAccessToken);
        print("refreshAccessToken: Success. New access token stored.");
        return newAccessToken;
      } else {
        print("refreshAccessToken: Failed - Server responded with ${response.statusCode}: ${response.body}");
        // If refresh fails (e.g., token expired or revoked), log user out fully
        // Pass false to logout to indicate it's not a user-initiated action
        await logout(revokeTokenOnServer: false); // Clear local tokens without server revocation attempt if refresh failed
        throw SessionExpiredException(); // Signal session expiration
      }
    } catch (e) {
      print("refreshAccessToken: Network or other error during refresh: $e");
      // Handle network errors or other issues during refresh
      if (e is! SessionExpiredException) {
        // Avoid double logout if already handled
        await logout(revokeTokenOnServer: false); // Clear local tokens without server revocation
      }
      // Ensure session expiration is signalled regardless of error type during refresh
      throw SessionExpiredException();
    }
  }


  // --- Logout ---
  // MODIFIED: Removed server revocation, only deletes local access token
  Future<void> logout({bool revokeTokenOnServer = true /* Optional: Allow skipping server call */}) async {
    print("logout: Initiating logout process. Revoke on server: $revokeTokenOnServer");

    // --- REMOVED Server Revocation Call ---
    // final refreshToken = await getRefreshToken();
    // if (revokeTokenOnServer && refreshToken != null) { /* ... server call ... */ }
    // --- END REMOVAL ---

    print("logout: Deleting local access token.");
    await _deleteLocalTokens(); // This now only deletes the access token
    // Biometric preference is NOT disabled here
    print("logout: Local cleanup complete (access token deleted).");
  }
  // --- END MODIFICATION ---


  // --- Biometric Methods ---
  Future<bool> isDeviceSupported() async {
    if (kIsWeb || _localAuth == null) return false; // Not supported on web or if auth object is null
    try {
      return await _localAuth!.isDeviceSupported();
    } catch (e) {
      print("Error checking biometric support: $e");
      return false;
    }
  }

  Future<bool> canCheckBiometrics() async {
    if (kIsWeb || _localAuth == null) return false;
    try {
      return await _localAuth!.canCheckBiometrics;
    } catch (e) {
      print("Error in canCheckBiometrics: $e");
      return false;
    }
  }


  Future<bool> authenticateWithBiometrics(String reason) async {
    if (kIsWeb || _localAuth == null) return false;
    try {
      // Corrected: Pass AuthenticationOptions to options parameter
      return await _localAuth!.authenticate(
        localizedReason: reason,
        // options: const AuthenticationOptions( // Pass AuthenticationOptions here
        //   stickyAuth: true, // Keep prompt open after failed attempt
          biometricOnly: true, // Only allow biometrics, no device PIN/Passcode fallback
        // ),
      );
    } catch (e) {
      print("Biometric authentication error: $e");
      return false;
    }
  }

  Future<void> enableBiometrics() async {
    await _saveBiometricPreference(true);
  }

  Future<void> disableBiometrics() async {
    await _saveBiometricPreference(false);
  }

  Future<bool> isBiometricsEnabled() async {
    // Check device support first
    bool supported = await isDeviceSupported();
    if (!supported) return false;

    final prefs = await SharedPreferences.getInstance();
    final bool isEnabled = prefs.getBool('biometrics_enabled') ?? false;
    // print("AuthService isBiometricsEnabled: Read preference: $isEnabled"); // Optional: Log reads
    return isEnabled;
  }

  Future<void> _saveBiometricPreference(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometrics_enabled', enabled);
    print("AuthService _saveBiometricPreference: Saved preference: $enabled"); // LOGGING
  }
}