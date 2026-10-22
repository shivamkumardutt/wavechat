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

  // Register a new user.
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
            'name': name.trim(),
            'email': email.trim().toLowerCase(),
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

  // Login and securely store the JWT.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email.trim().toLowerCase(),
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

  Future<String?> getAuthToken() {
    return _storage.read(key: _tokenKey);
  }

  Future<String?> getCurrentUserName() {
    return _storage.read(key: _userNameKey);
  }

  Future<bool> isLoggedIn() async {
  final token = await _storage.read(key: _tokenKey);

  if (token == null || token.isEmpty) {
    return false;
  }

  try {
    final response = await http
        .get(
          Uri.parse('$baseUrl/conversations'),
          headers: {
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 401) {
      await logout();
      return false;
    }

    // Keep the session if the server is temporarily unavailable.
    return response.statusCode != 403 &&
        response.statusCode < 500;
  } catch (_) {
    // A network failure alone should not erase a valid session.
    return true;
  }
}

  // Create or retrieve a conversation with a registered user by email.
  // The backend must implement POST /api/v1/conversations.
  Future<Map<String, dynamic>> createConversation({
    required String email,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedEmail.isEmpty) {
      throw Exception('Email is required to start a conversation.');
    }

    final response = await http
        .post(
          Uri.parse('$baseUrl/conversations'),
          headers: await _authHeaders(jsonContent: true),
          body: jsonEncode({'email': normalizedEmail}),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Failed to create conversation'));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['conversation'] is! Map || data['otherUser'] is! Map) {
      throw Exception('Invalid conversation response from server.');
    }

    return {
      'conversation': Map<String, dynamic>.from(data['conversation'] as Map),
      'otherUser': Map<String, dynamic>.from(data['otherUser'] as Map),
    };
  }

  Future<void> logout() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _userNameKey);
  }

  Future<Map<String, String>> _authHeaders({bool jsonContent = false}) async {
    final token = await _storage.read(key: _tokenKey);

    if (token == null || token.isEmpty) {
      throw Exception('Please log in to use WaveChat.');
    }

    return {
      if (jsonContent) 'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  // Fetch conversations belonging to the authenticated user.
  Future<List<Map<String, dynamic>>> fetchConversations() async {
    final response = await http.get(
      Uri.parse('$baseUrl/conversations'),
      headers: await _authHeaders(),
    );

    final Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Invalid response from server (${response.statusCode}).');
    }

    if (response.statusCode != 200) {
      final error = body['error'];
      final message = error is Map ? error['message']?.toString() : null;

      throw Exception(message ?? 'Could not load conversations.');
    }

    final rawConversations = body['conversations'];

    if (rawConversations is! List) {
      throw Exception('Server returned an invalid conversation list.');
    }

    return rawConversations
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  // Fetch messages for an authorized conversation.
  Future<List<Map<String, dynamic>>> fetchMessages({
    required String conversationId,
  }) async {
    final normalizedId = conversationId.trim();

    if (normalizedId.isEmpty) {
      throw Exception('Conversation ID is required.');
    }

    final uri = Uri.parse('$baseUrl/messages')
        .replace(queryParameters: {'conversationId': normalizedId});

    final response = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception(_errorMessage(response, 'Failed to fetch messages'));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = data['messages'];

    if (items is! List) {
      throw Exception('Invalid messages response from server.');
    }

    return items.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  // Send a message. The backend derives senderId from the JWT.
  Future<Map<String, dynamic>> sendMessage({
    required String conversationId,
    required String clientMessageId,
    required String text,
    required String senderId,
    String? replyToMessageId,
  }) async {
    // senderId remains in the method signature for compatibility with
    // existing UI code; the server does not trust a client-supplied sender ID.
    final normalizedText = text.trim();

    if (conversationId.trim().isEmpty) {
      throw Exception('Conversation ID is required.');
    }

    if (clientMessageId.trim().isEmpty) {
      throw Exception('Client message ID is required.');
    }

    if (normalizedText.isEmpty) {
      throw Exception('Message text cannot be empty.');
    }

    final response = await http
        .post(
          Uri.parse('$baseUrl/messages'),
          headers: await _authHeaders(jsonContent: true),
          body: jsonEncode({
            'conversationId': conversationId.trim(),
            'clientMessageId': clientMessageId.trim(),
            'text': normalizedText,
              'replyToMessageId': replyToMessageId,
          }),
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200 && response.statusCode != 201) {
      throw Exception(_errorMessage(response, 'Failed to send message'));
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (data['message'] is! Map) {
      throw Exception('Invalid message response from server.');
    }

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
      // Use a status-based fallback for a non-JSON response.
    }

    return '$fallback (${response.statusCode})';
  }
}
