import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'locale_map.dart';

/// Possible states of the TTS engine as observed by the UI.
enum TtsState { idle, loading, playing, error }

/// Self-contained Text-to-Speech service.
///
/// Usage:
///   final svc = TtsService();
///   await svc.speak(text, 'Türkçe');
///   await svc.stop();
///   svc.dispose();            // call from State.dispose()
///
/// Listen to [state] to drive the UI icon (idle -> play, loading -> spinner,
/// playing -> stop).
class TtsService {
  TtsService() {
    _init();
  }

  // Public state
  final ValueNotifier<TtsState> state = ValueNotifier(TtsState.idle);

  // Internal
  final FlutterTts _tts = FlutterTts();

  void _init() {
    _tts.setStartHandler(() {
      state.value = TtsState.playing;
    });

    _tts.setCompletionHandler(() {
      state.value = TtsState.idle;
    });

    _tts.setCancelHandler(() {
      state.value = TtsState.idle;
    });

    _tts.setErrorHandler((msg) {
      debugPrint('[TtsService] error: $msg');
      state.value = TtsState.error;
    });
  }

  // Public API

  /// Returns the BCP-47 locale string for [langCode], or null if unmapped.
  static String resolveLocale(String langCode) => AppLocaleMap.resolveLocale(langCode);

  /// Speaks [text] in the language identified by [langCode].
  ///
  /// [langCode] can be a key like 'Türkçe'.
  /// If the locale is unavailable on the device, returns silently after
  /// resetting state to [TtsState.idle].
  Future<void> speak(String text, String langCode) async {
    if (text.trim().isEmpty) return;

    final locale = AppLocaleMap.resolveLocale(langCode);

    state.value = TtsState.loading;

    try {
      await _tts.stop();

      final available = await _tts.isLanguageAvailable(locale);
      if (available != 1 && available != true) {
        debugPrint('[TtsService] Locale $locale not available on this device.');
        state.value = TtsState.idle;
        return;
      }

      await _tts.setLanguage(locale);
      await _tts.setSpeechRate(0.8);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);

      await _tts.speak(text);
      // TtsState.playing is set by setStartHandler.
    } catch (e) {
      debugPrint('[TtsService] speak() threw: $e');
      state.value = TtsState.error;
    }
  }

  /// Stops any ongoing speech and resets state to [TtsState.idle].
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    state.value = TtsState.idle;
  }

  /// Releases underlying [FlutterTts] resources.
  /// Must be called from the owning widget's [State.dispose].
  void dispose() {
    _tts.stop();
    state.dispose();
  }
}