import 'dart:async'; // Import for StreamController
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:local_auth/local_auth.dart'; // Import local_auth
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/api_service.dart'; // To send token to backend

class AuthProvider with ChangeNotifier {
  // Pass LocalAuthentication instance to AuthService
  final AuthService _authService = AuthService(LocalAuthentication());
  // --- NEW: Add ApiService instance ---
  final ApiService _apiService = ApiService();
  // --- END NEW ---

  bool _isAuthenticated = false;
  String? _username;
  bool _isBiometricsGloballyEnabled = false; // Add state for biometric preference

  // --- NEW: Stream for in-app notifications ---
  final _notificationStreamController = StreamController<RemoteMessage>.broadcast();
  Stream<RemoteMessage> get notificationStream => _notificationStreamController.stream;
  // --- END NEW ---

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;
  bool get isBiometricsGloballyEnabled => _isBiometricsGloballyEnabled; // Getter

  AuthProvider() {
    _loadBiometricPreference();
  }

  @override
  void dispose() {
    _notificationStreamController.close(); // Close the stream
    super.dispose();
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
      await _loadBiometricPreference();
      // --- NEW: Init FCM on session verification ---
      _initFCM();
      // --- END NEW ---
    } else {
      _isAuthenticated = false;
      _username = null;
      _isBiometricsGloballyEnabled = false;
    }
    notifyListeners();
  }


  void login(String username) {
    _isAuthenticated = true;
    _username = username;
    _loadBiometricPreference();
    // --- NEW: Init FCM on login ---
    _initFCM();
    // --- END NEW ---
    notifyListeners();
  }

  // Make logout async to handle API call and token deletion
  Future<void> logout() async {
    await _authService.logout(); // Calls AuthService.logout() which ONLY deletes access token now
    _isAuthenticated = false;
    _username = null; // Clear username in provider state
    notifyListeners();
  }


  // Method to update biometric preference
  Future<void> setBiometricPreference(bool enabled) async {
    if (enabled) {
      bool supported = await _authService.isDeviceSupported();
      bool canCheck = await _authService.canCheckBiometrics();
      if (supported && canCheck) {
        await _authService.enableBiometrics();
        _isBiometricsGloballyEnabled = true;
      } else {
        print("Attempted to enable biometrics on unsupported device.");
        _isBiometricsGloballyEnabled = false;
        await _authService.disableBiometrics();
      }
    } else {
      await _authService.disableBiometrics();
      _isBiometricsGloballyEnabled = false;
    }
    notifyListeners();
  }

  // --- NEW: FCM/Notification Logic ---
  Future<void> _initFCM() async {
    print("Initializing FCM and requesting permission...");
    final messaging = FirebaseMessaging.instance;

    // 1. Request permission from the user (for iOS and Web)
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('FCM: User granted permission');

      // 2. Get the FCM token
      try {
        final fcmToken = await messaging.getToken();
        if (fcmToken != null) {
          print('FCM Token: $fcmToken');

          // 3. Send the token to your backend
          await _apiService.updateFcmToken(fcmToken);
          print('FCM Token successfully sent to backend.');

          // Optional: Listen for token refreshes
          messaging.onTokenRefresh.listen((newToken) {
            print('FCM Token refreshed: $newToken');
            _apiService.updateFcmToken(newToken).catchError((e) {
              print("Error sending refreshed FCM token: $e");
            });
          });

        } else {
          print('FCM: Unable to get token (fcmToken is null).');
        }
      } catch (e) {
        print('Error getting/sending FCM token: $e');
      }

    } else {
      print('FCM: User declined or has not accepted permission');
    }

    // Handle incoming messages (when app is in foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('FCM: Got a message whilst in the foreground!');
      print('Message data: ${message.data}');
      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification!.title} - ${message.notification!.body}');

        // --- NEW: Broadcast the message to the UI ---
        _notificationStreamController.add(message);
        // --- END NEW ---
      }
    });
  }
  // --- END NEW ---

  AuthService get authService => _authService;
}