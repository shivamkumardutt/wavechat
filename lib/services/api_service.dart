
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService({
    this.baseUrl = 'http://172.16.20.172:3000/api/v1',
    FlutterSecureStorage? storage,
  }) : _storage = storage ?? const FlutterSecureStorage();

  final String baseUrl;
  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'wavechat_jwt';
  static const String _userIdKey = 'wavechat_user_id';
  static const String _userNameKey = 'wavechat_user_name';

  Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/register'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'name': name,
            'email': email,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 201) {
      throw Exception(_errorMessage(response, 'Registration failed'));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Map<String, dynamic>.from(data['user'] as Map);
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Login failed'));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final token = data['token'] as String?;
    final user = Map<String, dynamic>.from(data['user'] as Map);
    final userId = user['id'] as String?;
    final userName = user['name'] as String?;

    if (token == null || token.isEmpty || userId == null || userId.isEmpty) {
      throw Exception('Login response is missing token or user information.');
    }

    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _userIdKey, value: userId);
    if (userName != null) {
      await _storage.write(key: _userNameKey, value: userName);
    }

    return user;
  }

  Future<String?> getCurrentUserId() {
    return _storage.read(key: _userIdKey);
  }

  Future<String?> getCurrentUserName() {
    return _storage.read(key: _userNameKey);
  }

  Future<bool> isLoggedIn() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _userNameKey);
  }

  Future<Map<String, String>> _authHeaders({
    bool jsonContent = false,
  }) async {
    final token = await _storage.read(key: _tokenKey);

    if (token == null || token.isEmpty) {
      throw Exception('Please log in to use WaveChat.');
    }

    return {
      if (jsonContent) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  Future<List<Map<String, dynamic>>> fetchMessages({
    required String conversationId,
  }) async {
    final uri = Uri.parse('$baseUrl/messages').replace(
      queryParameters: {'conversationId': conversationId},
    );

    final response = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Failed to fetch messages'));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['messages'] as List<dynamic>;

    return items
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String clientMessageId,
    required String text,
    required String senderId,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/messages'),
          headers: await _authHeaders(jsonContent: true),
          body: jsonEncode({
            'conversationId': conversationId,
            'clientMessageId': clientMessageId,
            'text': text,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_errorMessage(response, 'Failed to send message'));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return Map<String, dynamic>.from(data['message'] as Map);
  }

  String _errorMessage(http.Response response, String fallback) {
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final error = data['error'];

      if (error is Map && error['message'] is String) {
        return error['message'] as String;
      }
    } catch (_) {
      // Fall back to a status-based error.
    }

    return '$fallback (${response.statusCode})';
  }
}
