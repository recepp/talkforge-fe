import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user's Koyu/Açık (dark/light) theme choice. Defaults to
/// dark, matching the design handoff's default and the app's existing look.
class ThemeProvider extends ChangeNotifier {
  static const _prefKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;

  ThemeProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved == 'light') {
      _themeMode = ThemeMode.light;
      notifyListeners();
    }
  }

  Future<void> setDark() => _set(ThemeMode.dark);
  Future<void> setLight() => _set(ThemeMode.light);

  Future<void> _set(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode == ThemeMode.dark ? 'dark' : 'light');
  }
}
