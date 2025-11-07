import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'package:local_auth/local_auth.dart'; // Import local_auth
import 'package:firebase_messaging/firebase_messaging.dart';
import '../services/api_service.dart'; // To send token to backend
import 'dart:async'; // For StreamController

class AuthProvider with ChangeNotifier {
  // Pass LocalAuthentication instance to AuthService
  final AuthService _authService = AuthService(LocalAuthentication());
  // --- NEW: Add ApiService instance ---
  final ApiService _apiService = ApiService();
  // --- END NEW ---

  bool _isAuthenticated = false;
  String? _username;
  bool _isBiometricsGloballyEnabled = false; // Add state for biometric preference

  // --- NEW: Profile Picture State ---
  String? _profilePictureUrl;
  // --- END NEW ---

  // --- NEW: Notification Stream ---
  final StreamController<RemoteMessage> _notificationStreamController = StreamController.broadcast();
  Stream<RemoteMessage> get notificationStream => _notificationStreamController.stream;
  // --- END NEW ---

  bool get isAuthenticated => _isAuthenticated;
  String? get username => _username;
  String? get profilePictureUrl => _profilePictureUrl; // <-- NEW GETTER
  bool get isBiometricsGloballyEnabled => _isBiometricsGloballyEnabled; // Getter

  AuthProvider() {
    _loadBiometricPreference();
  }

  Future<void> _loadBiometricPreference() async {
    _isBiometricsGloballyEnabled = await _authService.isBiometricsEnabled();
    notifyListeners(); // Notify after loading initial preference
  }

  // --- MODIFIED: To handle full user object ---
  Future<void> checkAuth() async {
    // verifyTokenAndGetUser now returns a Map<String, dynamic>?
    final userData = await _authService.verifyTokenAndGetUser();

    if (userData != null) {
      _isAuthenticated = true;
      _username = userData['username'];
      _profilePictureUrl = userData['profile_picture_url']; // <-- NEW
      await _loadBiometricPreference();
      _initFCM();
    } else {
      _isAuthenticated = false;
      _username = null;
      _profilePictureUrl = null; // <-- NEW
      _isBiometricsGloballyEnabled = false;
    }
    notifyListeners();
  }
  // --- END MODIFICATION ---

  // --- MODIFIED: To fetch user data on login ---
  Future<void> login(String username) async {
    _isAuthenticated = true;
    _username = username;
    _loadBiometricPreference();
    _initFCM();

    // --- NEW: Fetch full user data after login ---
    try {
      // We just logged in, so our token is valid. Call /users/me
      final userData = await _authService.verifyTokenAndGetUser();
      if (userData != null) {
        _profilePictureUrl = userData['profile_picture_url'];
      }
    } catch (e) {
      print("Error fetching user data after login: $e");
    }
    // --- END NEW ---

    notifyListeners();
  }
  // --- END MODIFICATION ---

  // --- NEW: updateUser method ---
  void updateUser(Map<String, dynamic> userData) {
    _username = userData['username'];
    _profilePictureUrl = userData['profile_picture_url'];
    notifyListeners();
  }
  // --- END NEW ---

  // Make logout async to handle API call and token deletion
  Future<void> logout() async {
    await _authService.logout(); // Calls AuthService.logout()
    _isAuthenticated = false;
    _username = null; // Clear username in provider state
    _profilePictureUrl = null; // <-- NEW: Clear PFP
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
        // --- NEW: Pass notification to stream ---
        _notificationStreamController.add(message);
        // --- END NEW ---
      }
    });
  }
  // --- END NEW ---

  // --- NEW: Dispose Stream ---
  @override
  void dispose() {
    _notificationStreamController.close();
    super.dispose();
  }
  // --- END NEW ---

  AuthService get authService => _authService;
}