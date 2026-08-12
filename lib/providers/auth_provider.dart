import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _email;
  String? _nickname;
  String? _role;
  String? _language;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get email => _email;
  String? get nickname => _nickname;
  String? get role => _role;
  String get language => _language ?? 'tr';

  AuthProvider() {
    ApiService.onUnauthorized = _handleUnauthorized;
    checkAuthStatus();
  }

  Future<void> _handleUnauthorized() async {
    _isAuthenticated = false;
    _email = null;
    _nickname = null;
    _role = null;
    _language = null;
    notifyListeners();
  }

  // Restore session from local storage on app start
  Future<void> checkAuthStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');
    if (token != null && token.trim().isNotEmpty && ApiService.isValidToken(token)) {
      _isAuthenticated = true;
      _email = prefs.getString('user_email');
      _nickname = prefs.getString('user_nickname');
      _role = prefs.getString('user_role');
      _language = prefs.getString('user_language') ?? 'tr';
    } else {
      await prefs.clear();
      _isAuthenticated = false;
    }
    _isLoading = false;
    notifyListeners();
  }

  // Login
  Future<void> login(String email, String password) async {
    try {
      final data = await ApiService.login(email, password);
      _isAuthenticated = true;
      _email = data['email'];
      _nickname = data['nickname'];
      _role = data['role'];
      _language = data['language'] ?? 'tr';
      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      rethrow;
    }
  }

  // Signup
  Future<void> signup(String email, String password, String nickname) async {
    try {
      final data = await ApiService.signup(email, password, nickname);
      _isAuthenticated = true;
      _email = data['email'];
      _nickname = data['nickname'];
      _role = data['role'];
      _language = data['language'] ?? 'tr';
      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      rethrow;
    }
  }

  // Login with a Google ID token
  Future<void> loginWithGoogle(String googleToken) async {
    try {
      final data = await ApiService.googleLogin(googleToken);
      _isAuthenticated = true;
      _email = data['email'];
      _nickname = data['nickname'];
      _role = data['role'];
      _language = data['language'] ?? 'tr';
      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      rethrow;
    }
  }

  // Update Language Preference
  Future<void> updateLanguage(String newLang) async {
    try {
      await ApiService.updateLanguage(newLang);
      _language = newLang;
      notifyListeners();
    } catch (e) {
      rethrow;
    }
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _isAuthenticated = false;
    _email = null;
    _nickname = null;
    _role = null;
    _language = null;
    notifyListeners();
  }
}
