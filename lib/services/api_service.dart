import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class ApiService {
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
    };
  }

  // Parses response and throws exceptions on API errors
  static dynamic _parseResponse(http.Response response) {
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
    final data = _parseResponse(response) as Map<String, dynamic>;

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
    final data = _parseResponse(response) as Map<String, dynamic>;

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
    final headers = await _getHeaders(language);
    final response = await http.put(
      Uri.parse('${Constants.baseUrl}/user/language'),
      headers: headers,
      body: jsonEncode({'language': language}),
    );
    final data = _parseResponse(response) as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_language', language);
    return data;
  }

  // Fetch Dialogue Tree List
  static Future<List<dynamic>> getTalkRequests() async {
    final response = await http.get(
      Uri.parse('${Constants.baseUrl}/talks'),
      headers: await _getHeaders(),
    );
    final data = _parseResponse(response);
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
    final headers = await _getHeaders();
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

    final response = await http.post(
      Uri.parse('${Constants.baseUrl}/talks'),
      headers: headers,
      body: jsonEncode(body),
    );
    return _parseResponse(response) as Map<String, dynamic>;
  }

  // Delete Dialogue Request
  static Future<void> deleteTalkRequest(int id) async {
    final headers = await _getHeaders();
    final response = await http.delete(
      Uri.parse('${Constants.baseUrl}/talks/$id'),
      headers: headers,
    );
    _parseResponse(response);
  }
}
