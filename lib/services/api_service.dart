import 'dart:convert';
import 'package:flutter/material.dart'; // Added for 'Color' object
import 'package:http/http.dart' as http; // Ensure http is imported
import 'dart:async'; // Added for FutureOr, Future, Completer
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/leaderboard.dart';
import '../models/drink_entry.dart';
import 'auth_service.dart'; // Added for SessionExpiredException and AuthService
// --- Corrected Import ---
import 'package:http_interceptor/http_interceptor.dart'; // Defines InterceptorContract
import 'package:local_auth/local_auth.dart'; // Import for LocalAuthentication

// Custom Exception
class SessionExpiredException implements Exception {
  final String message = "Your session has expired. Please log in again.";
  SessionExpiredException();
}

// --- The Interceptor Logic with Queuing ---
class AuthInterceptor implements InterceptorContract {
  AuthService? _authService;
  final LocalAuthentication _localAuth = LocalAuthentication();

  AuthService get authService {
    _authService ??= AuthService(_localAuth);
    return _authService!;
  }

  bool _isRefreshing = false;
  // Completer to signal when refresh is done, holds the new token or null
  Completer<String?>? _refreshTokenCompleter;

  @override
  FutureOr<http.BaseRequest> interceptRequest({required http.BaseRequest request}) async {
    // If a refresh is happening, wait for it to complete before adding token
    if (_isRefreshing && !(request.url.toString().contains('/token/refresh'))) {
      print("Interceptor: Refresh in progress, waiting for completion before sending ${request.url}");
      final newToken = await _refreshTokenCompleter?.future;
      if (newToken != null) {
        print("Interceptor: Refresh completed, adding new token to ${request.url}");
        request.headers['Authorization'] = 'Bearer $newToken';
      } else {
        print("Interceptor: Refresh failed while waiting, request ${request.url} likely to fail.");
        // Allow request to proceed, it will likely get a 401 and trigger logout flow
      }
    } else {
      // Add current token if not refreshing or if it's the refresh request itself
      final token = await authService.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }
    }

    // Explicitly set Content-Type for relevant methods if not already set
    if ((request.method == 'POST' || request.method == 'PUT') &&
        request is! http.MultipartRequest &&
        !request.headers.containsKey('Content-Type')) {
      request.headers['Content-Type'] = 'application/json; charset=UTF-8';
    }
    return request;
  }


  @override
  Future<http.BaseResponse> interceptResponse({required http.BaseResponse response}) async {
    final isRefreshUrl = response.request?.url.toString().contains('/token/refresh') ?? false;

    // --- Case 1: Need to Refresh ---
    if (!isRefreshUrl && response.statusCode == 401 && !_isRefreshing) {
      print("Interceptor: Detected 401 for ${response.request?.url}. Starting refresh.");
      _isRefreshing = true;
      _refreshTokenCompleter = Completer<String?>(); // Create completer for others to wait on

      String? newAccessToken;
      try {
        newAccessToken = await authService.refreshAccessToken();
        _refreshTokenCompleter?.complete(newAccessToken); // Signal completion (success or fail)

        if (newAccessToken != null) {
          print("Interceptor: Refresh successful. Retrying original request.");
          _isRefreshing = false; // Reset flag AFTER completer is done

          // Retry the original request (logic largely unchanged)
          final originalRequest = response.request!;
          http.BaseRequest clonedRequest;

          // Cloning logic... (simplified for brevity, assume previous version is ok for now)
          if (originalRequest is http.Request) {
            clonedRequest = http.Request(originalRequest.method, originalRequest.url)
              ..headers.addAll(originalRequest.headers)
              ..bodyBytes = originalRequest.bodyBytes
              ..encoding = originalRequest.encoding;
          } else if (originalRequest is http.MultipartRequest) { /* ... multipart cloning ... */
            clonedRequest = http.MultipartRequest(originalRequest.method, originalRequest.url)
              ..headers.addAll(originalRequest.headers)
              ..fields.addAll(originalRequest.fields);
            final mpOriginalRequest = originalRequest;
            for (var file in mpOriginalRequest.files) {
              try {
                final List<int> fileBytes = await file.finalize().toBytes();
                if (clonedRequest is http.MultipartRequest) {
                  clonedRequest.files.add(http.MultipartFile.fromBytes(
                    file.field, fileBytes, filename: file.filename, contentType: file.contentType,
                  ));
                }
              } catch (e) { print("Error re-adding file '${file.filename}' during retry: $e"); }
            }
          } else if (originalRequest is http.StreamedRequest) { /* ... streamed error ... */
            print("Warning: Retrying StreamedRequest is not fully supported.");
            _isRefreshing = false;
            _refreshTokenCompleter?.complete(null); // Signal failure
            throw SessionExpiredException();
          } else { /* ... other error ... */
            _isRefreshing = false;
            _refreshTokenCompleter?.complete(null);
            throw UnimplementedError("Unsupported request type: ${originalRequest.runtimeType}");
          }

          clonedRequest.headers['Authorization'] = 'Bearer $newAccessToken';
          if (clonedRequest is! http.MultipartRequest && !clonedRequest.headers.containsKey('Content-Type')) {
            clonedRequest.headers['Content-Type'] = 'application/json; charset=UTF-8';
          }

          print("Interceptor: Sending retried request to ${clonedRequest.url}");
          final client = http.Client();
          final http.StreamedResponse streamedResponse = await client.send(clonedRequest);
          print("Interceptor: Retried request completed with status ${streamedResponse.statusCode}");

          final http.Response finalResponse = await http.Response.fromStream(streamedResponse);
          client.close();
          print("Interceptor: Converted retried response.");
          return finalResponse;

        } else {
          // Refresh failed (refreshAccessToken should throw)
          print("Interceptor: refreshAccessToken returned null or threw. Refresh failed.");
          _isRefreshing = false;
          _refreshTokenCompleter?.complete(null); // Signal failure
          throw SessionExpiredException();
        }
      } catch (e) {
        print("Interceptor: Error during refresh/retry process: $e");
        _isRefreshing = false;
        _refreshTokenCompleter?.complete(null); // Signal failure
        if (e is SessionExpiredException) rethrow;
        throw SessionExpiredException();
      }
    }
    // --- Case 2: Refresh Already in Progress ---
    else if (!isRefreshUrl && response.statusCode == 401 && _isRefreshing) {
      print("Interceptor: Received 401 for ${response.request?.url} while refresh in progress. Waiting...");
      final newAccessToken = await _refreshTokenCompleter?.future; // Wait for the ongoing refresh

      if (newAccessToken != null) {
        print("Interceptor: Ongoing refresh succeeded. Retrying ${response.request?.url}.");
        // Retry this request now that refresh is done (similar logic as above)
        final originalRequest = response.request!;
        http.BaseRequest clonedRequest;
        // ... (Cloning logic as above) ...
        if (originalRequest is http.Request) {
          clonedRequest = http.Request(originalRequest.method, originalRequest.url)
            ..headers.addAll(originalRequest.headers)
            ..bodyBytes = originalRequest.bodyBytes
            ..encoding = originalRequest.encoding;
        } else if (originalRequest is http.MultipartRequest) { /* ... multipart cloning ... */
          clonedRequest = http.MultipartRequest(originalRequest.method, originalRequest.url)
            ..headers.addAll(originalRequest.headers)
            ..fields.addAll(originalRequest.fields);
          final mpOriginalRequest = originalRequest;
          for (var file in mpOriginalRequest.files) {
            try {
              final List<int> fileBytes = await file.finalize().toBytes();
              if (clonedRequest is http.MultipartRequest) {
                clonedRequest.files.add(http.MultipartFile.fromBytes(
                  file.field, fileBytes, filename: file.filename, contentType: file.contentType,
                ));
              }
            } catch (e) { print("Error re-adding file '${file.filename}' during retry: $e"); }
          }
        } else if (originalRequest is http.StreamedRequest) { /* ... streamed error ... */
          print("Warning: Retrying StreamedRequest is not fully supported.");
          throw SessionExpiredException(); // Fail fast if we waited and still failed
        } else { /* ... other error ... */
          throw UnimplementedError("Unsupported request type: ${originalRequest.runtimeType}");
        }

        clonedRequest.headers['Authorization'] = 'Bearer $newAccessToken';
        if (clonedRequest is! http.MultipartRequest && !clonedRequest.headers.containsKey('Content-Type')) {
          clonedRequest.headers['Content-Type'] = 'application/json; charset=UTF-8';
        }

        final client = http.Client();
        final http.StreamedResponse streamedResponse = await client.send(clonedRequest);
        final http.Response finalResponse = await http.Response.fromStream(streamedResponse);
        client.close();
        print("Interceptor: Retried waiting request ${clonedRequest.url} completed with status ${finalResponse.statusCode}");
        return finalResponse;

      } else {
        print("Interceptor: Ongoing refresh failed while ${response.request?.url} was waiting. Throwing SessionExpiredException.");
        // If the refresh failed while we were waiting, this request also fails.
        throw SessionExpiredException();
      }
    }

    // If not 401, or it's the refresh URL, return original response
    return response;
  }


  @override
  Future<bool> shouldInterceptRequest() async {
    return true; // Intercept all requests
  }

  @override
  Future<bool> shouldInterceptResponse() async {
    return true; // Intercept all responses
  }
}


class ApiService {
  final String _baseUrl = "https://api.oscarkohn.com";
  final _storage = const FlutterSecureStorage();

  // Use the interceptor client for all requests
  final http.Client client = InterceptedClient.build(
    interceptors: [AuthInterceptor()],
  );

  // Helper to get headers with Content-Type, Auth interceptor will add Authorization
  Map<String, String> _getJsonHeaders() {
    // Interceptor now handles Content-Type for JSON if needed, but explicit is fine
    return {'Content-Type': 'application/json; charset=UTF-8'};
  }


  // Helper to handle response and potential SessionExpiredException
  // Expects http.Response because interceptor converts StreamedResponse after retry
  Future<http.Response> _handleResponse(Future<http.Response> Function() requestAction) async {
    try {
      final response = await requestAction();

      // Interceptor handles 401 retries. If we get here with 401, it means
      // the refresh failed or the retried request *also* failed with 401.
      if (response.statusCode == 401) {
        print("_handleResponse: Received final 401. Throwing SessionExpiredException.");
        // We might get here if the refresh token is expired/invalid
        // or if the retried request immediately gets another 401 (e.g., server issue)
        // Ensure logout is triggered if not already happening.
        await AuthInterceptor().authService.logout(); // Trigger logout for safety
        throw SessionExpiredException();
      }
      // Check for other client/server errors
      else if (response.statusCode < 200 || response.statusCode >= 300) {
        String errorMessage = 'API Error (${response.statusCode})';
        try {
          final body = jsonDecode(response.body);
          if (body['detail'] != null) {
            errorMessage += ': ${body['detail']}';
          } else {
            errorMessage += ': ${response.reasonPhrase ?? response.body}';
          }
        } catch (_) {
          errorMessage += ': ${response.reasonPhrase ?? response.body}';
        }
        print("_handleResponse: " + errorMessage);
        throw Exception(errorMessage);
      }
      // Success
      return response;
    } on SessionExpiredException {
      print("_handleResponse: Caught SessionExpiredException. Rethrowing...");
      rethrow; // Propagate session expiration upwards
    } catch (e) {
      print("_handleResponse: Network or other error during API call: $e");
      if (e is Exception) {
        throw Exception('Request failed: ${e.toString()}');
      } else {
        throw Exception('An unexpected error occurred: $e');
      }
    }
  }


  // --- Leaderboard Methods ---
  Future<List<Leaderboard>> getUserLeaderboards() async {
    final response = await _handleResponse(() => client.get(
      Uri.parse('$_baseUrl/leaderboards/'),
    ));
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((lb) => Leaderboard.fromJson(lb)).toList();
  }

  Future<LeaderboardDetail> getLeaderboardDetails(int leaderboardId) async {
    final response = await _handleResponse(() => client.get(
      Uri.parse('$_baseUrl/leaderboards/$leaderboardId'),
    ));
    return LeaderboardDetail.fromJson(json.decode(response.body));
  }

  // REVERTED: Re-added startDate parameter
  Future<Leaderboard> createLeaderboard({
    required String name,
    required DateTime startDate, // RE-ADDED
    DateTime? endDate,
    String? goalCategory,
    double? goalValue,
  }) async {
    final body = {
      'name': name,
      'start_date': startDate.toIso8601String(), // RE-ADDED (send UTC from create screen)
      'end_date': endDate?.toIso8601String(),
      'goal_category': goalCategory,
      'goal_value': goalValue,
    };
    body.removeWhere((key, value) => value == null && key != 'end_date');
    if (endDate == null) body.remove('end_date');

    final response = await _handleResponse(() => client.post(
      Uri.parse('$_baseUrl/leaderboards/'),
      headers: _getJsonHeaders(), // Explicitly set Content-Type header
      body: jsonEncode(body),
    ));
    return Leaderboard.fromJson(json.decode(response.body));
  }
  // --- END REVERSION ---


  Future<void> joinLeaderboard(String inviteCode) async {
    await _handleResponse(() => client.post(
      Uri.parse('$_baseUrl/leaderboards/join/$inviteCode'),
    ));
  }

  Future<void> leaveLeaderboard(int leaderboardId) async {
    await _handleResponse(() => client.delete(
      Uri.parse('$_baseUrl/leaderboards/$leaderboardId/leave'),
    ));
  }

  Future<void> deleteLeaderboard(int leaderboardId) async {
    await _handleResponse(() => client.delete(
      Uri.parse('$_baseUrl/leaderboards/$leaderboardId'),
    ));
  }

  // --- Drink Methods ---
  Future<List<DrinkEntry>> getUserDrinks({DateTime? startDate, DateTime? endDate}) async {
    final queryParameters = {
      if (startDate != null) 'start_date': startDate.toIso8601String(),
      if (endDate != null) 'end_date': endDate.toIso8601String(),
    };

    final uri = Uri.parse('$_baseUrl/drinks/me').replace(queryParameters: queryParameters.isNotEmpty ? queryParameters : null);

    final response = await _handleResponse(() => client.get(uri));
    List jsonResponse = json.decode(response.body);
    return jsonResponse.map((drink) => DrinkEntry.fromJson(drink)).toList();
  }

  Future<void> addDrink(DrinkEntry drink) async {
    await _handleResponse(() => client.post(
      Uri.parse('$_baseUrl/drinks/'),
      headers: _getJsonHeaders(), // Explicitly set Content-Type header
      body: jsonEncode({
        'type': drink.type,
        'volume': drink.volume,
        'abv': drink.abv,
        'units': drink.units,
        'location': drink.location,
        // 'timestamp': drink.timestamp.toIso8601String(), // REMOVED
      }),
    ));
  }

  Future<void> updateUsername(String newUsername) async {
    await _handleResponse(() => client.put(
      Uri.parse('$_baseUrl/users/me/username'),
      headers: _getJsonHeaders(), // Explicitly set Content-Type header
      body: jsonEncode({'new_username': newUsername}),
    ));
  }

  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _handleResponse(() => client.put(
      Uri.parse('$_baseUrl/users/me/password'),
      headers: _getJsonHeaders(), // Explicitly set Content-Type header
      body: jsonEncode({
        'current_password': currentPassword,
        'new_password': newPassword,
      }),
    ));
  }

  Future<void> deleteDrink(int? drinkId) async { // Allow null ID temporarily
    if (drinkId == null) {
      print("Error: Attempted to delete drink with null ID.");
      throw Exception("Cannot delete drink without an ID.");
    }
    await _handleResponse(() => client.delete(
      Uri.parse('$_baseUrl/drinks/$drinkId'),
    ));
  }

  // --- Theme Methods ---
  Future<List<Color>> getAiUIPalette(List<Color?> lockedColors) async {
    final input = lockedColors.map((color) {
      if (color == null) return "N";
      return [color.red, color.green, color.blue];
    }).toList();

    try {
      final response = await http.post(
        Uri.parse('http://colormind.io/api/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'ui',
          'input': input,
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        final List<dynamic> rgbList = jsonResponse['result'];
        if (rgbList.length != 5) {
          print("Warning: Colormind API did not return 5 colors.");
          return List.generate(5, (_) => Colors.grey);
        }
        return rgbList.map((rgb) {
          if (rgb is List && rgb.length == 3 && rgb.every((val) => val is int && val >= 0 && val <= 255)) {
            return Color.fromARGB(255, rgb[0], rgb[1], rgb[2]);
          } else {
            print("Warning: Invalid RGB format received from Colormind API: $rgb");
            return Colors.grey;
          }
        }).toList();
      } else {
        print("Failed to load AI palette: ${response.statusCode} ${response.body}");
        throw Exception('Failed to load AI palette (${response.statusCode})');
      }
    } catch (e) {
      print("Error loading AI palette: $e");
      throw Exception('Failed to load AI palette: Network error or invalid response.');
    }
  }
}