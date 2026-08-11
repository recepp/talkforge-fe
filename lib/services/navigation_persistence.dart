import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'url_strategy_stub.dart'
    if (dart.library.html) 'url_strategy_web.dart' as url_helper;

class NavigationState {
  final int tabIndex;
  final String? detailType; // 'talk' or 'room'
  final int? detailId;

  NavigationState({
    required this.tabIndex,
    this.detailType,
    this.detailId,
  });
}

class NavigationPersistence {
  static const String _keyTab = 'saved_tab_index';
  static const String _keyDetailType = 'saved_detail_type';
  static const String _keyDetailId = 'saved_detail_id';

  /// Synchronously parse initial tab index from Web URL if present
  static int initialTabIndexFromUrl() {
    if (kIsWeb) {
      try {
        final fragment = Uri.base.fragment;
        final parsed = parseHash(fragment);
        if (parsed != null) {
          return parsed.tabIndex;
        }
      } catch (_) {}
    }
    return 0;
  }

  /// Save current tab and detail screen state
  static Future<void> saveState({
    required int tabIndex,
    String? detailType,
    int? detailId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyTab, tabIndex);

    if (detailType != null && detailId != null) {
      await prefs.setString(_keyDetailType, detailType);
      await prefs.setInt(_keyDetailId, detailId);
    } else {
      await prefs.remove(_keyDetailType);
      await prefs.remove(_keyDetailId);
    }

    // Update Web URL hash
    if (kIsWeb) {
      String hash = '';
      if (detailType == 'talk' && detailId != null) {
        hash = '#/talks/$detailId';
      } else if (detailType == 'room' && detailId != null) {
        hash = '#/rooms/$detailId';
      } else {
        switch (tabIndex) {
          case 1:
            hash = '#/rooms';
            break;
          case 2:
            hash = '#/invites';
            break;
          case 3:
            hash = '#/profile';
            break;
          case 0:
          default:
            hash = '#/talks';
            break;
        }
      }
      url_helper.setWebUrlHash(hash);
    }
  }

  /// Restore saved navigation state (checking web URL fragment first, then SharedPreferences)
  static Future<NavigationState> restoreState() async {
    // 1. Try web URL fragment first if on Web
    if (kIsWeb) {
      final fragment = url_helper.getWebUrlHash();
      final parsed = parseHash(fragment);
      if (parsed != null) {
        // Sync SharedPreferences
        await saveState(
          tabIndex: parsed.tabIndex,
          detailType: parsed.detailType,
          detailId: parsed.detailId,
        );
        return parsed;
      }
    }

    // 2. Fallback to SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final tabIndex = prefs.getInt(_keyTab) ?? 0;
    final detailType = prefs.getString(_keyDetailType);
    final detailId = prefs.getInt(_keyDetailId);

    return NavigationState(
      tabIndex: (tabIndex >= 0 && tabIndex <= 3) ? tabIndex : 0,
      detailType: detailType,
      detailId: detailId,
    );
  }

  static NavigationState? parseHash(String hash) {
    if (hash.isEmpty) return null;
    String clean = hash;
    if (clean.startsWith('#')) clean = clean.substring(1);
    if (clean.startsWith('/')) clean = clean.substring(1);
    if (clean.isEmpty) return null;

    final parts = clean.split('/');
    if (parts.isEmpty) return null;

    final section = parts[0];
    if (section == 'talks' || section == 'talk') {
      if (parts.length >= 2 && int.tryParse(parts[1]) != null) {
        return NavigationState(
          tabIndex: 0,
          detailType: 'talk',
          detailId: int.parse(parts[1]),
        );
      }
      return NavigationState(tabIndex: 0);
    } else if (section == 'rooms' || section == 'room') {
      if (parts.length >= 2 && int.tryParse(parts[1]) != null) {
        return NavigationState(
          tabIndex: 1,
          detailType: 'room',
          detailId: int.parse(parts[1]),
        );
      }
      return NavigationState(tabIndex: 1);
    } else if (section == 'invites') {
      return NavigationState(tabIndex: 2);
    } else if (section == 'profile') {
      return NavigationState(tabIndex: 3);
    }

    return null;
  }

  static Future<void> clearState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyTab);
    await prefs.remove(_keyDetailType);
    await prefs.remove(_keyDetailId);
    if (kIsWeb) {
      url_helper.setWebUrlHash('');
    }
  }
}
