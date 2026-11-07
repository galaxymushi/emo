import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceService {
  final SpeechToText _speech = SpeechToText();
  final FlutterTts _tts = FlutterTts();

  bool initialized = false;
  bool _speechReady = false;
  bool available = false;
  bool listening = false;
  bool ttsEnabled = true;
  double rate = 0.5;
  String? error;

  VoidCallback? onListeningChanged;
  ValueChanged<String>? onPartial;
  ValueChanged<String>? onFinal;
  ValueChanged<String>? onError;

  /// Prepares text-to-speech only. Speech recognition is initialized on the
  /// first mic tap so Android does not show a microphone prompt at launch.
  Future<void> init() async {
    if (initialized) return;
    initialized = true;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(rate);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
    } catch (_) {}
  }

  Future<bool> _initSpeech() async {
    if (_speechReady) return available;
    _speechReady = true;
    try {
      available = await _speech.initialize(
        onStatus: _handleStatus,
        onError: (e) {
          error = e.errorMsg;
          listening = false;
          onListeningChanged?.call();
          onError?.call(e.errorMsg);
        },
      );
    } catch (_) {
      available = false;
    }
    return available;
  }

  void _handleStatus(String status) {
    final isListening = status == SpeechToText.listeningStatus;
    if (listening != isListening) {
      listening = isListening;
      onListeningChanged?.call();
    }
  }

  Future<bool> start() async {
    await init();
    await _initSpeech();
    if (!available) {
      error = 'Voice input is not available on this phone.';
      onError?.call(error!);
      return false;
    }
    String? localeId;
    try {
      final locales = await _speech.locales();
      for (final locale in locales) {
        if (locale.localeId.replaceAll('-', '_').toLowerCase() == 'en_us') {
          localeId = locale.localeId;
          break;
        }
      }
    } catch (_) {}
    try {
      await _speech.listen(
        onResult: (result) {
          if (result.recognizedWords.isEmpty) return;
          onPartial?.call(result.recognizedWords);
          if (result.finalResult) {
            onFinal?.call(result.recognizedWords);
          }
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          localeId: localeId,
        ),
      );
      listening = true;
      onListeningChanged?.call();
      return true;
    } catch (e) {
      error = 'I could not start the microphone.';
      onError?.call(error!);
      listening = false;
      onListeningChanged?.call();
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
    listening = false;
    onListeningChanged?.call();
  }

  Future<void> speak(String text) async {
    if (!ttsEnabled || text.trim().isEmpty) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }

  Future<void> setRate(double value) async {
    rate = value;
    try {
      await _tts.setSpeechRate(value);
    } catch (_) {}
  }

  Future<void> setEnabled(bool value) async {
    ttsEnabled = value;
    if (!value) {
      try {
        await _tts.stop();
      } catch (_) {}
    }
  }
}
