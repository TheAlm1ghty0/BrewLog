import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/leaderboard.dart';
import '../models/drink_entry.dart';
import 'auth_service.dart'; // Import AuthService to use its methods

// --- NEW: Custom Exception ---
// We'll throw this when the refresh token itself is invalid
// so the UI can catch it and log the user out.
class SessionExpiredException implements Exception {
  final String message;
  SessionExpiredException(this.message);
  @override
  String toString() => message;
}

class ApiService {
  final String _baseUrl = "https://api.oscarkohn.com";
  final _storage = const FlutterSecureStorage();

  // --- NEW: Instance of AuthService ---
  final AuthService _authService = AuthService();

  // --- NEW: Helper to store the new access token ---
  Future<void> _saveNewAccessToken(String token) async {
    await _storage.write(key: 'auth_token', value: token);
  }

  // --- NEW: The core logic wrapper ---
  /// Makes an authenticated API request, handling token refresh automatically.
  Future<http.Response> _makeAuthenticatedRequest(
      // This "requestCallback" is the function we want to run,
      // e.g., http.get(...) or http.post(...)
      Future<http.Response> Function(Map<String, String> headers) requestCallback,
      ) async {

    // 1. Get current headers and make the first attempt
    Map<String, String> headers = await _getHeaders();
    http.Response response = await requestCallback(headers);

    if (response.statusCode == 401) {
      // 2. Token expired. Try to refresh.
      final String? refreshToken = await _authService.getRefreshToken();
      if (refreshToken == null) {
        // We have no refresh token, so we can't recover.
        throw SessionExpiredException("Session expired. Please log in again.");
      }

      try {
        // 3. Call the /token/refresh endpoint
        final refreshResponse = await http.post(
          Uri.parse('$_baseUrl/token/refresh'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'refresh_token': refreshToken}),
        );

        if (refreshResponse.statusCode == 200) {
          // 4. Refresh was successful!
          final data = jsonDecode(refreshResponse.body);
          final newAccessToken = data['access_token'];

          // Save the new token
          await _saveNewAccessToken(newAccessToken);

          // 5. Retry the original request with the new token
          headers = await _getHeaders(); // This will now get the new token
          response = await requestCallback(headers);
        } else {
          // 6. Refresh failed. The refresh token is invalid. Time to log out.
          throw SessionExpiredException("Session expired. Please log in again.");
        }
      } catch (e) {
        // 7. The refresh request itself failed (e.g., no internet)
        throw SessionExpiredException("Could not refresh session. Please log in again.");
      }
    }

    // 8. Return the response (either from the 1st or 2nd try)
    return response;
  }

  Future<Map<String, String>> _getHeaders() async {
    String? token = await _storage.read(key: 'auth_token');
    return {
      'Content-Type': 'application/json; charset=UTF-8',
      'Authorization': 'Bearer $token',
    };
  }

  // --- Leaderboard Methods (Now use the wrapper) ---
  Future<List<Leaderboard>> getUserLeaderboards() async {
    final response = await _makeAuthenticatedRequest(
          (headers) => http.get(
        Uri.parse('$_baseUrl/leaderboards/'),
        headers: headers,
      ),
    );
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((lb) => Leaderboard.fromJson(lb)).toList();
    } else {
      throw Exception('Failed to load leaderboards');
    }
  }

  Future<LeaderboardDetail> getLeaderboardDetails(int leaderboardId) async {
    final response = await _makeAuthenticatedRequest(
          (headers) => http.get(
        Uri.parse('$_baseUrl/leaderboards/$leaderboardId'),
        headers: headers,
      ),
    );
    if (response.statusCode == 200) {
      return LeaderboardDetail.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to load leaderboard details');
    }
  }

  Future<Leaderboard> createLeaderboard({
    required String name,
    required DateTime startDate,
    DateTime? endDate,
    String? goalCategory,
    double? goalValue,
  }) async {
    final body = {
      'name': name,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'goal_category': goalCategory,
      'goal_value': goalValue,
    };
    body.removeWhere((key, value) => value == null);
    final encodedBody = jsonEncode(body);

    final response = await _makeAuthenticatedRequest(
          (headers) => http.post(
        Uri.parse('$_baseUrl/leaderboards/'),
        headers: headers,
        body: encodedBody,
      ),
    );

    if (response.statusCode == 200) {
      return Leaderboard.fromJson(json.decode(response.body));
    } else {
      throw Exception('Failed to create leaderboard');
    }
  }

  Future<void> joinLeaderboard(String inviteCode) async {
    final response = await _makeAuthenticatedRequest(
          (headers) => http.post(
        Uri.parse('$_baseUrl/leaderboards/join/$inviteCode'),
        headers: headers,
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to join leaderboard. The code may be invalid.');
    }
  }

  Future<void> leaveLeaderboard(int leaderboardId) async {
    final response = await _makeAuthenticatedRequest(
          (headers) => http.delete(
        Uri.parse('$_baseUrl/leaderboards/$leaderboardId/leave'),
        headers: headers,
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to leave leaderboard');
    }
  }

  Future<void> deleteLeaderboard(int leaderboardId) async {
    final response = await _makeAuthenticatedRequest(
          (headers) => http.delete(
        Uri.parse('$_baseUrl/leaderboards/$leaderboardId'),
        headers: headers,
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete leaderboard. You may not be the creator.');
    }
  }

  // --- Drink Methods (Now use the wrapper) ---
  Future<List<DrinkEntry>> getUserDrinks({DateTime? startDate, DateTime? endDate}) async {
    final queryParameters = {
      if (startDate != null) 'start_date': startDate.toIso8601String(),
      if (endDate != null) 'end_date': endDate.toIso8601String(),
    };
    final uri = Uri.parse('$_baseUrl/drinks/me').replace(queryParameters: queryParameters.isNotEmpty ? queryParameters : null);

    final response = await _makeAuthenticatedRequest(
          (headers) => http.get(uri, headers: headers),
    );
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((drink) => DrinkEntry.fromJson(drink)).toList();
    } else {
      throw Exception('Failed to load user drinks');
    }
  }

  Future<void> addDrink(DrinkEntry drink) async {
    final encodedBody = jsonEncode({
      'type': drink.type,
      'volume': drink.volume,
      'abv': drink.abv,
      'units': drink.units,
      'location': drink.location,
    });

    final response = await _makeAuthenticatedRequest(
          (headers) => http.post(
        Uri.parse('$_baseUrl/drinks/'),
        headers: headers,
        body: encodedBody,
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to add drink');
    }
  }

  Future<void> deleteDrink(int drinkId) async {
    final response = await _makeAuthenticatedRequest(
          (headers) => http.delete(
        Uri.parse('$_baseUrl/drinks/$drinkId'),
        headers: headers,
      ),
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to delete drink');
    }
  }

  // --- User Profile Methods (Now use the wrapper) ---
  Future<void> updateUsername(String newUsername) async {
    final encodedBody = jsonEncode({'new_username': newUsername});

    final response = await _makeAuthenticatedRequest(
          (headers) => http.put(
        Uri.parse('$_baseUrl/users/me/username'),
        headers: headers,
        body: encodedBody,
      ),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to update username.');
    }
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final encodedBody = jsonEncode({
      'current_password': currentPassword,
      'new_password': newPassword,
    });

    final response = await _makeAuthenticatedRequest(
          (headers) => http.put(
        Uri.parse('$_baseUrl/users/me/password'),
        headers: headers,
        body: encodedBody,
      ),
    );
    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(body['detail'] ?? 'Failed to update password.');
    }
  }
}