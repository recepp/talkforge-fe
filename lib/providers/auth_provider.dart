import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String? _email;
  String? _nickname;
  String? _role;
  String? _subscriptionTier;
  String? _language;

  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get email => _email;
  String? get nickname => _nickname;
  String? get role => _role;
  String get subscriptionTier => _subscriptionTier ?? 'free';
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
    _subscriptionTier = null;
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
      _subscriptionTier = prefs.getString('user_subscription_tier') ?? 'free';
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
      _subscriptionTier = data['subscription_tier'] ?? 'free';
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
      _subscriptionTier = data['subscription_tier'] ?? 'free';
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
      _subscriptionTier = data['subscription_tier'] ?? 'free';
      _language = data['language'] ?? 'tr';
      notifyListeners();
    } catch (e) {
      _isAuthenticated = false;
      rethrow;
    }
  }

  // Update User Nickname
  Future<void> updateNickname(String newNickname) async {
    try {
      await ApiService.updateNickname(newNickname);
      _nickname = newNickname;
      notifyListeners();
    } catch (e) {
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

  // Update Subscription Tier locally & in preferences
  Future<void> updateSubscriptionTier(String newTier) async {
    _subscriptionTier = newTier;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_subscription_tier', newTier);
    notifyListeners();
  }

  // Logout
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    _isAuthenticated = false;
    _email = null;
    _nickname = null;
    _role = null;
    _subscriptionTier = null;
    _language = null;
    notifyListeners();
  }
}
