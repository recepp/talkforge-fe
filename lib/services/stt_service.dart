import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'locale_map.dart';

/// Possible states of the STT engine as observed by the UI.
enum SttState { idle, listening, processing, error }

/// Self-contained Speech-to-Text service.
///
/// Usage:
///   final svc = SttService();
///   await svc.startListening('Türkçe', (text) => ...);
///   await svc.stopListening();
///   svc.dispose(); // in State.dispose()
class SttService {
  final SpeechToText _stt = SpeechToText();
  final ValueNotifier<SttState> state = ValueNotifier(SttState.idle);

  bool _isInitialized = false;

  /// Initializes the underlying SpeechToText instance.
  Future<bool> _ensureInitialized() async {
    if (_isInitialized) return true;
    try {
      _isInitialized = await _stt.initialize(
        onError: (err) {
          debugPrint('[SttService] onError: ${err.errorMsg}');
          state.value = SttState.error;
        },
        onStatus: (status) {
          debugPrint('[SttService] onStatus: $status');
          if (status == 'listening') {
            state.value = SttState.listening;
          } else if (status == 'notListening' || status == 'done') {
            if (state.value == SttState.listening) {
              state.value = SttState.idle;
            }
          }
        },
      );
      return _isInitialized;
    } catch (e) {
      debugPrint('[SttService] initialization failed: $e');
      state.value = SttState.error;
      return false;
    }
  }

  /// Starts listening for speech in the language given by [langCodeOrName].
  ///
  /// [onResult] is called with (recognizedText, isFinal).
  Future<void> startListening(
    String langCodeOrName,
    void Function(String recognizedText, bool isFinal) onResult,
  ) async {
    state.value = SttState.processing;

    final ready = await _ensureInitialized();
    if (!ready) {
      state.value = SttState.error;
      return;
    }

    final localeId = AppLocaleMap.resolveLocale(langCodeOrName);

    try {
      state.value = SttState.listening;
      await _stt.listen(
        onResult: (result) {
          debugPrint('[SttService] onResult: words="${result.recognizedWords}", finalResult=${result.finalResult}');
          onResult(result.recognizedWords, result.finalResult);
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          partialResults: true,
          localeId: localeId,
        ),
      );
    } catch (e) {
      debugPrint('[SttService] listen error: $e');
      state.value = SttState.error;
    }
  }

  /// Stops ongoing listening and resets to idle.
  Future<void> stopListening() async {
    try {
      if (_stt.isListening) {
        await _stt.stop();
      }
    } catch (_) {}
    state.value = SttState.idle;
  }

  /// Toggles between listening and idle states.
  Future<void> toggleListening(
    String langCodeOrName,
    void Function(String recognizedText, bool isFinal) onResult,
  ) async {
    if (state.value == SttState.listening) {
      await stopListening();
    } else {
      await startListening(langCodeOrName, onResult);
    }
  }

  /// Releases resources.
  void dispose() {
    stopListening();
    state.dispose();
  }
}
