import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../screens/login_screen.dart';

class ApiService {
<<<<<<< HEAD
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static Future<void> Function()? onUnauthorized;
  static bool _isHandling401 = false;

  static bool isValidToken(String token) {
    for (int i = 0; i < token.length; i++) {
      if (token.codeUnitAt(i) > 127) return false;
    }
    return true;
  }

  static Future<Map<String, String>> _getHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token == null || token.trim().isEmpty || !isValidToken(token)) {
      await handle401();
      throw Exception('Oturum sonlandı.');
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${token.trim()}',
=======
  static Future<Map<String, String>> _getHeaders([String? langCode]) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userLang = prefs.getString('user_language') ?? 'tr';
    final preferredLang = langCode ?? userLang;

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Accept-Language': preferredLang,
      if (token != null) 'Authorization': 'Bearer $token',
>>>>>>> 22be27876936c8ecadab9f7227724b527a893061
    };
  }

  static bool _isAuthError(dynamic e) {
    final err = e.toString().toLowerCase();
    return err.contains('iso-8859-1') ||
           err.contains('headers') ||
           err.contains('fetch') ||
           err.contains('unauthorized') ||
           err.contains('bearer');
  }

  static Future<http.Response> _safeGet(Uri url) async {
    final headers = await _getHeaders();
    try {
      return await http.get(url, headers: headers);
    } catch (e) {
      if (_isAuthError(e)) {
        await handle401();
      }
      rethrow;
    }
  }

  static Future<http.Response> _safePost(Uri url, {Object? body}) async {
    final headers = await _getHeaders();
    try {
      return await http.post(url, headers: headers, body: body);
    } catch (e) {
      if (_isAuthError(e)) {
        await handle401();
      }
      rethrow;
    }
  }

  static Future<http.Response> _safePut(Uri url, {Object? body}) async {
    final headers = await _getHeaders();
    try {
      return await http.put(url, headers: headers, body: body);
    } catch (e) {
      if (_isAuthError(e)) {
        await handle401();
      }
      rethrow;
    }
  }

  static Future<http.Response> _safeDelete(Uri url) async {
    final headers = await _getHeaders();
    try {
      return await http.delete(url, headers: headers);
    } catch (e) {
      if (_isAuthError(e)) {
        await handle401();
      }
      rethrow;
    }
  }

  // Handle 401 Unauthorized globally: clear session data and reset navigator stack
  static Future<void> handle401() async {
    if (_isHandling401) return;
    _isHandling401 = true;
    try {
      if (onUnauthorized != null) {
        await onUnauthorized!();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } finally {
      _isHandling401 = false;
    }
  }

  // Parses response and throws exceptions on API errors
  static Future<dynamic> _parseResponse(http.Response response, {String? endpoint}) async {
    final body = response.body;
    final statusCode = response.statusCode;

    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } catch (_) {
      decoded = body;
    }

    if (statusCode >= 200 && statusCode < 300) {
      return decoded;
    } else if (statusCode == 401 && endpoint != '/auth/login' && endpoint != '/auth/signup') {
      await handle401();
      String errorMessage = 'Oturum süresi doldu. Lütfen tekrar giriş yapın.';
      if (decoded is Map && decoded.containsKey('error')) {
        errorMessage = decoded['error'].toString();
      }
      throw Exception(errorMessage);
    } else {
      String errorMessage = 'İşlem başarısız oldu';
      if (decoded is Map && decoded.containsKey('error')) {
        errorMessage = decoded['error'].toString();
      }
      throw Exception(errorMessage);
    }
  }

  // Fetch dynamic multi-language talk types
  static Future<List<dynamic>> getTalkTypes({String? langCode}) async {
    final headers = await _getHeaders(langCode);
    final response = await http.get(
      Uri.parse('${Constants.baseUrl}/talk-types'),
      headers: headers,
    );
    final data = _parseResponse(response);
    if (data is List) {
      return data;
    }
    return [];
  }

  // Authenticate user with Email and Password
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('${Constants.baseUrl}/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = await _parseResponse(response, endpoint: '/auth/login') as Map<String, dynamic>;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', data['token'] ?? '');
    await prefs.setString('user_email', data['email'] ?? '');
    await prefs.setString('user_nickname', data['nickname'] ?? '');
    await prefs.setString('user_role', data['role'] ?? 'user');
    await prefs.setString('user_language', data['language'] ?? 'tr');
    await prefs.setInt('user_id', data['user_id'] ?? 0);

    return data;
  }

  // Register a new user
  static Future<Map<String, dynamic>> signup(String email, String password, String nickname) async {
    final response = await http.post(
      Uri.parse('${Constants.baseUrl}/auth/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'nickname': nickname,
        'avatar': '👤',
      }),
    );
    final data = await _parseResponse(response, endpoint: '/auth/signup') as Map<String, dynamic>;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', data['token'] ?? '');
    await prefs.setString('user_email', data['email'] ?? '');
    await prefs.setString('user_nickname', data['nickname'] ?? '');
    await prefs.setString('user_role', data['role'] ?? 'user');
    await prefs.setString('user_language', data['language'] ?? 'tr');
    await prefs.setInt('user_id', data['user_id'] ?? 0);

    return data;
  }

  // Update User Language Preference
  static Future<Map<String, dynamic>> updateLanguage(String language) async {
<<<<<<< HEAD
    final response = await _safePut(
=======
    final headers = await _getHeaders(language);
    final response = await http.put(
>>>>>>> 22be27876936c8ecadab9f7227724b527a893061
      Uri.parse('${Constants.baseUrl}/user/language'),
      body: jsonEncode({'language': language}),
    );
    final data = await _parseResponse(response, endpoint: '/user/language') as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_language', language);
    return data;
  }

  // Fetch Dialogue Tree List
  static Future<List<dynamic>> getTalkRequests() async {
    final response = await _safeGet(Uri.parse('${Constants.baseUrl}/talks'));
    final data = await _parseResponse(response, endpoint: '/talks');
    if (data is List) {
      return data;
    }
    return [];
  }

  // Create Dialogue Request
  static Future<Map<String, dynamic>> createTalkRequest({
    required String mode,
    String? language,
    String? place,
    String? topic,
    String? speechType,
    String? customSpeechType,
    int? duration,
    String? instruction,
    int? parentId,
  }) async {
    final body = {
      'mode': mode,
      if (mode == 'new') 'language': language,
      if (mode == 'new') 'place': place,
      if (mode == 'new') 'topic': topic,
      if (mode == 'new') 'speech_type': speechType,
      if (mode == 'new' && customSpeechType != null && customSpeechType.isNotEmpty)
        'custom_speech_type': customSpeechType,
      if (mode == 'new') 'duration': duration,
      if (mode == 'update') 'instruction': instruction,
      if (mode == 'update') 'parent_id': parentId,
    };

    final response = await _safePost(
      Uri.parse('${Constants.baseUrl}/talks'),
      body: jsonEncode(body),
    );
    return await _parseResponse(response, endpoint: '/talks') as Map<String, dynamic>;
  }

  // Delete Dialogue Request
  static Future<void> deleteTalkRequest(int id) async {
    final response = await _safeDelete(Uri.parse('${Constants.baseUrl}/talks/$id'));
    await _parseResponse(response, endpoint: '/talks/$id');
  }
}
