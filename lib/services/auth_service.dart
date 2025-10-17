import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final String _baseUrl = "https://api.oscarkohn.com";
  final _storage = const FlutterSecureStorage();

  Future<String?> getToken() async {
    return await _storage.read(key: 'auth_token');
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: 'auth_token');
  }

  Future<void> login(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/token'),
      // Send as form data, not JSON
      body: {
        'username': username,
        'password': password,
      },
      // The http package automatically sets the correct 'Content-Type' header
      // for a Map<String, String> body: 'application/x-www-form-urlencoded'
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      await _storage.write(key: 'auth_token', value: data['access_token']);
    } else {
      // Throw an exception to be caught by the UI
      throw Exception('Failed to log in. Please check your credentials.');
    }
  }

  Future<void> register(String username, String password) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/users/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'username': username,
        'password': password,
      }),
    );

    if (response.statusCode != 200) {
      // You can add more specific error handling here based on response body
      throw Exception('Failed to register user.');
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async {
    String? token = await getToken();
    if (token == null) {
      throw Exception('Not authenticated');
    }

    final response = await http.get(
      Uri.parse('$_baseUrl/users/me'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch user data.');
    }
  }
}

