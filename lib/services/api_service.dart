import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import '../screens/login_screen.dart';

class ApiService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static Future<void> Function()? onUnauthorized;
  static bool _isHandling401 = false;

  static bool isValidToken(String token) {
    for (int i = 0; i < token.length; i++) {
      if (token.codeUnitAt(i) > 127) return false;
    }
    return true;
  }

  static Future<Map<String, String>> _getHeaders([String? langCode]) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    final userLang = prefs.getString('user_language') ?? 'tr';
    final preferredLang = langCode ?? userLang;

    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Accept-Language': preferredLang,
      if (token != null && token.trim().isNotEmpty && isValidToken(token))
        'Authorization': 'Bearer ${token.trim()}',
    };
  }

  static bool _isAuthError(dynamic e) {
    final err = e.toString().toLowerCase();
    return err.contains('iso-8859-1') ||
           err.contains('unauthorized') ||
           err.contains('invalid token');
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

  static Future<http.Response> _safePatch(Uri url, {Object? body}) async {
    final headers = await _getHeaders();
    try {
      return await http.patch(url, headers: headers, body: body);
    } catch (e) {
      if (_isAuthError(e)) {
        await handle401();
      }
      rethrow;
    }
  }

  // Handle 401 Unauthorized / 403 Forbidden globally: clear session data and reset navigator stack
  static Future<void> handle401([String? message]) async {
    if (_isHandling401) return;
    _isHandling401 = true;
    try {
      if (onUnauthorized != null) {
        await onUnauthorized!();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      navigatorKey.currentState?.pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => LoginScreen(initialErrorMessage: message)),
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
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      return decoded;
    } else if (statusCode == 429) {
      String errorMessage = 'Kullanım limitinize ulaştınız.';
      if (decoded is Map && decoded.containsKey('error')) {
        errorMessage = decoded['error'].toString();
      }
      showQuotaExceededDialog(errorMessage);
      throw Exception(errorMessage);
    } else if (endpoint != '/auth/login' && endpoint != '/auth/signup' && endpoint != '/auth/google' &&
               (statusCode == 401 || (statusCode == 403 && decoded is Map && decoded['error'].toString().toLowerCase().contains('suspended')))) {
      String errorMessage = 'Oturum süresi doldu. Lütfen tekrar giriş yapın.';
      if (decoded is Map && decoded.containsKey('error')) {
        errorMessage = decoded['error'].toString();
      }
      if (errorMessage.toLowerCase().contains('authorization header') || errorMessage.toLowerCase().contains('token')) {
        errorMessage = 'Oturum süresi doldu. Lütfen tekrar giriş yapın.';
      }
      await handle401(errorMessage);
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
    final data = await _parseResponse(response);
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
    await prefs.setString('user_subscription_tier', data['subscription_tier'] ?? 'free');
    await prefs.setString('user_language', data['language'] ?? 'tr');
    await prefs.setInt('user_id', data['user_id'] ?? 0);

    return data;
  }

  // Authenticate user with a Google ID token
  static Future<Map<String, dynamic>> googleLogin(String googleToken) async {
    final response = await http.post(
      Uri.parse('${Constants.baseUrl}/auth/google'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'google_token': googleToken}),
    );
    final data = await _parseResponse(response, endpoint: '/auth/google') as Map<String, dynamic>;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', data['token'] ?? '');
    await prefs.setString('user_email', data['email'] ?? '');
    await prefs.setString('user_nickname', data['nickname'] ?? '');
    await prefs.setString('user_role', data['role'] ?? 'user');
    await prefs.setString('user_subscription_tier', data['subscription_tier'] ?? 'free');
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
    await prefs.setString('user_subscription_tier', data['subscription_tier'] ?? 'free');
    await prefs.setString('user_language', data['language'] ?? 'tr');
    await prefs.setInt('user_id', data['user_id'] ?? 0);

    return data;
  }

  // Update User Language Preference
  static Future<Map<String, dynamic>> updateLanguage(String language) async {
    final response = await _safePut(
      Uri.parse('${Constants.baseUrl}/user/language'),
      body: jsonEncode({'language': language}),
    );
    final data = await _parseResponse(response, endpoint: '/user/language') as Map<String, dynamic>;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_language', language);
    return data;
  }

  // Fetch Dialogue Tree List
  // [archived]: when true, fetches archived talks only; when false or null, shows non-archived (default)
  static Future<List<dynamic>> getTalkRequests({bool? archived}) async {
    final uri = archived == true
        ? Uri.parse('${Constants.baseUrl}/talks?archived=true')
        : Uri.parse('${Constants.baseUrl}/talks');
    final response = await _safeGet(uri);
    final data = await _parseResponse(response, endpoint: '/talks');
    if (data is List) {
      return data;
    }
    return [];
  }

  // Update a root talk's organizational metadata (favorite, archived, tags).
  // Only fields provided (non-null) are sent to the backend.
  static Future<Map<String, dynamic>> patchTalkMeta(
    int id, {
    bool? isFavorite,
    bool? isArchived,
    List<String>? tags,
  }) async {
    final body = <String, dynamic>{};
    if (isFavorite != null) body['is_favorite'] = isFavorite;
    if (isArchived != null) body['is_archived'] = isArchived;
    if (tags != null) body['tags'] = tags;
    final response = await _safePatch(
      Uri.parse('${Constants.baseUrl}/talks/$id/meta'),
      body: jsonEncode(body),
    );
    return await _parseResponse(response, endpoint: '/talks/$id/meta') as Map<String, dynamic>;
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
    String? selectedText,
    String? generatedText,
    int? roomId,
  }) async {
    final body = {
      'mode': mode,
      if (mode == 'new') 'language': language,
      if (mode == 'new') 'place': place,
      if (mode == 'new') 'topic': topic,
      if (mode == 'new') 'speech_type': speechType,
      if (mode == 'new' && roomId != null) 'room_id': roomId,
      if (mode == 'new' && customSpeechType != null && customSpeechType.isNotEmpty)
        'custom_speech_type': customSpeechType,
      if (mode == 'new') 'duration': duration,
      if (mode == 'update' || mode == 'partial_update' || mode == 'manual_update')
        'instruction': instruction,
      if (mode == 'update' || mode == 'partial_update' || mode == 'manual_update')
        'parent_id': parentId,
      if ((mode == 'partial_update' || mode == 'manual_update') && selectedText != null)
        'selected_text': selectedText,
      if (mode == 'manual_update' && generatedText != null)
        'generated_text': generatedText,
    };

    final response = await _safePost(
      Uri.parse('${Constants.baseUrl}/talks'),
      body: jsonEncode(body),
    );
    return await _parseResponse(response, endpoint: '/talks') as Map<String, dynamic>;
  }

  // Preview a talk's text translated into another language. Not persisted —
  // no new version is created; the returned text is for display only.
  static Future<Map<String, dynamic>> translateTalk(int talkId, String language) async {
    final response = await _safePost(
      Uri.parse('${Constants.baseUrl}/talks/$talkId/translate'),
      body: jsonEncode({'language': language}),
    );
    return await _parseResponse(response, endpoint: '/talks/$talkId/translate') as Map<String, dynamic>;
  }

  // Delete Dialogue Request
  static Future<void> deleteTalkRequest(int id, {bool cascade = false}) async {
    final uri = cascade
        ? Uri.parse('${Constants.baseUrl}/talks/$id?cascade=true')
        : Uri.parse('${Constants.baseUrl}/talks/$id');
    final response = await _safeDelete(uri);
    await _parseResponse(response, endpoint: '/talks/$id');
  }

  // Create a shared room
  static Future<Map<String, dynamic>> createRoom(String name) async {
    final response = await _safePost(
      Uri.parse('${Constants.baseUrl}/rooms'),
      body: jsonEncode({'name': name}),
    );
    return await _parseResponse(response, endpoint: '/rooms') as Map<String, dynamic>;
  }

  // List rooms the current user is a member of
  static Future<List<dynamic>> getRooms() async {
    final response = await _safeGet(Uri.parse('${Constants.baseUrl}/rooms'));
    final data = await _parseResponse(response, endpoint: '/rooms');
    if (data is List) return data;
    return [];
  }

  // Get a single room's details (including members)
  static Future<Map<String, dynamic>> getRoom(int id) async {
    final response = await _safeGet(Uri.parse('${Constants.baseUrl}/rooms/$id'));
    return await _parseResponse(response, endpoint: '/rooms/$id') as Map<String, dynamic>;
  }

  // Invite (or update the role of) a member in a room by email
  static Future<Map<String, dynamic>> inviteRoomMember({
    required int roomId,
    required String email,
    required String role,
  }) async {
    final response = await _safePost(
      Uri.parse('${Constants.baseUrl}/rooms/$roomId/members'),
      body: jsonEncode({'email': email, 'role': role}),
    );
    return await _parseResponse(response, endpoint: '/rooms/$roomId/members') as Map<String, dynamic>;
  }

  // Leave a room
  static Future<Map<String, dynamic>> leaveRoom(int roomId) async {
    final response = await _safePost(
      Uri.parse('${Constants.baseUrl}/rooms/$roomId/leave'),
    );
    return await _parseResponse(response, endpoint: '/rooms/$roomId/leave') as Map<String, dynamic>;
  }

  // List a talk's discussion thread
  static Future<List<dynamic>> getTalkMessages(int talkId) async {
    final response = await _safeGet(Uri.parse('${Constants.baseUrl}/talks/$talkId/messages'));
    final data = await _parseResponse(response, endpoint: '/talks/$talkId/messages');
    if (data is List) return data;
    return [];
  }

  // Post a message to a talk's discussion thread
  static Future<Map<String, dynamic>> postTalkMessage(int talkId, String text) async {
    final response = await _safePost(
      Uri.parse('${Constants.baseUrl}/talks/$talkId/messages'),
      body: jsonEncode({'text': text}),
    );
    return await _parseResponse(response, endpoint: '/talks/$talkId/messages') as Map<String, dynamic>;
  }

  // Summarize a talk's discussion thread into a new "update" version
  static Future<Map<String, dynamic>> summarizeDiscussion(int talkId) async {
    final response = await _safePost(Uri.parse('${Constants.baseUrl}/talks/$talkId/messages/summarize'));
    return await _parseResponse(response, endpoint: '/talks/$talkId/messages/summarize') as Map<String, dynamic>;
  }

  // ── Invite / Approval API ──────────────────────────────────────────────────

  /// Returns the list of pending room invitations for the authenticated user.
  static Future<List<dynamic>> getInvites() async {
    final response = await _safeGet(Uri.parse('${Constants.baseUrl}/invites'));
    final data = await _parseResponse(response, endpoint: '/invites');
    if (data is List) return data;
    return [];
  }

  /// Accepts a pending invitation by its RoomMember ID.
  static Future<Map<String, dynamic>> acceptInvite(int inviteId) async {
    final response = await _safePost(Uri.parse('${Constants.baseUrl}/invites/$inviteId/accept'));
    return await _parseResponse(response, endpoint: '/invites/$inviteId/accept') as Map<String, dynamic>;
  }

  /// Declines a pending invitation by its RoomMember ID.
  static Future<Map<String, dynamic>> declineInvite(int inviteId) async {
    final response = await _safePost(Uri.parse('${Constants.baseUrl}/invites/$inviteId/decline'));
    return await _parseResponse(response, endpoint: '/invites/$inviteId/decline') as Map<String, dynamic>;
  }

  // ── Admin Panel API ────────────────────────────────────────────────────────

  /// Fetch overall platform statistics (Total users, total talks, status breakdown, Gemini API calls)
  static Future<Map<String, dynamic>> getAdminStats() async {
    final response = await _safeGet(Uri.parse('${Constants.baseUrl}/admin/stats'));
    final data = await _parseResponse(response, endpoint: '/admin/stats');
    return data as Map<String, dynamic>;
  }

  /// Fetch all users with usage stats and role/suspension state
  static Future<List<dynamic>> getAdminUsers() async {
    final response = await _safeGet(Uri.parse('${Constants.baseUrl}/admin/users'));
    final data = await _parseResponse(response, endpoint: '/admin/users');
    if (data is List) return data;
    return [];
  }

  /// Update a user's role, subscription tier, or suspension status
  static Future<Map<String, dynamic>> updateAdminUser(
    int userId, {
    String? role,
    String? subscriptionTier,
    bool? isSuspended,
  }) async {
    final body = <String, dynamic>{};
    if (role != null) body['role'] = role;
    if (subscriptionTier != null) body['subscription_tier'] = subscriptionTier;
    if (isSuspended != null) body['is_suspended'] = isSuspended;

    final response = await _safePatch(
      Uri.parse('${Constants.baseUrl}/admin/users/$userId'),
      body: jsonEncode(body),
    );
    return await _parseResponse(response, endpoint: '/admin/users/$userId') as Map<String, dynamic>;
  }

  /// Fetch all rooms with member & talk counts
  static Future<List<dynamic>> getAdminRooms() async {
    final response = await _safeGet(Uri.parse('${Constants.baseUrl}/admin/rooms'));
    final data = await _parseResponse(response, endpoint: '/admin/rooms');
    if (data is List) return data;
    return [];
  }

  /// Fetch user Gemini quota and usage statistics
  static Future<Map<String, dynamic>> getUserUsage() async {
    final response = await _safeGet(Uri.parse('${Constants.baseUrl}/user/usage'));
    final data = await _parseResponse(response, endpoint: '/user/usage');
    return data as Map<String, dynamic>;
  }

  // Get available subscription plans
  static Future<List<dynamic>> getSubscriptionPlans({String? langCode}) async {
    final headers = await _getHeaders(langCode);
    final response = await http.get(
      Uri.parse('${Constants.baseUrl}/plans'),
      headers: headers,
    );
    final data = await _parseResponse(response);
    if (data is List) {
      return data;
    }
    return [];
  }

  // Get user's current subscription details
  static Future<Map<String, dynamic>> getUserSubscription() async {
    final response = await _safeGet(Uri.parse('${Constants.baseUrl}/user/subscription'));
    final data = await _parseResponse(response);
    return data as Map<String, dynamic>;
  }

  // Subscribe to plan endpoint (prepares for payment gateway integration)
  static Future<Map<String, dynamic>> subscribeToPlan(String tier) async {
    final response = await _safePost(
      Uri.parse('${Constants.baseUrl}/user/subscription'),
      body: jsonEncode({'tier': tier}),
    );
    final data = await _parseResponse(response);
    return data as Map<String, dynamic>;
  }

  /// Shows a modal dialog alerting the user that their Gemini API quota limit has been exceeded.
  static void showQuotaExceededDialog([String? message]) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: const Color(0xFF1E212A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Kota Limiti Aşıldı',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          message ?? 'Gemini API kullanım limitinize ulaştınız. Lütfen daha sonra tekrar deneyin.',
          style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Anladım', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}


