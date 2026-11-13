import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'google_tts_service.dart';

class EmoVoice {
  const EmoVoice({required this.name, required this.locale});

  final String name;
  final String locale;

  bool get isEnglish {
    final l = locale.toLowerCase().replaceAll('_', '-');
    return l == 'en' || l.startsWith('en-');
  }

  bool get isUsEnglish {
    final l = locale.toLowerCase().replaceAll('_', '-');
    return l == 'en-us' || l.startsWith('en-us-');
  }

  /// Google's "network" voices are the neural, natural-sounding ones.
  bool get isNatural => name.toLowerCase().contains('network');

  String? get gender {
    final n = name.toLowerCase();
    if (n.contains('female')) return 'Female';
    if (n.contains('male')) return 'Male';
    return null;
  }

  String get languageName {
    final l = locale.toLowerCase().replaceAll('_', '-');
    const names = {
      'en-us': 'US English',
      'en-gb': 'UK English',
      'en-au': 'Australian English',
      'en-ca': 'Canadian English',
      'en-in': 'Indian English',
      'en-ie': 'Irish English',
      'en-nz': 'New Zealand English',
      'en-za': 'South African English',
      'en-sg': 'Singapore English',
      'en-ph': 'Philippine English',
    };
    return names[l] ?? locale;
  }

  String get label => [
        languageName,
        ?gender,
        if (isNatural) 'Natural',
      ].join(' · ');
}

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

  List<EmoVoice> voices = const [];
  EmoVoice? currentVoice;

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

  int _voiceScore(EmoVoice voice) {
    var score = 0;
    if (voice.isUsEnglish) {
      score += 100;
    } else if (voice.isEnglish) {
      score += 60;
    }
    if (voice.isNatural) score += 20;
    if (voice.gender != null) score += 2;
    return score;
  }

  /// Lists the voices the phone's TTS engine exposes, best first.
  Future<List<EmoVoice>> loadVoices() async {
    try {
      final raw = await _tts.getVoices;
      final found = <EmoVoice>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is! Map) continue;
          final name = item['name']?.toString() ?? '';
          final locale = item['locale']?.toString() ?? '';
          if (name.isEmpty || locale.isEmpty) continue;
          if (found.any((v) => v.name == name && v.locale == locale)) continue;
          found.add(EmoVoice(name: name, locale: locale));
        }
      }
      found.sort((a, b) {
        final byScore = _voiceScore(b).compareTo(_voiceScore(a));
        return byScore != 0 ? byScore : a.label.compareTo(b.label);
      });
      voices = found;
    } catch (_) {}
    return voices;
  }

  /// Natural US English first, then any US English, then the first voice.
  EmoVoice? get preferredVoice {
    if (voices.isEmpty) return null;
    for (final voice in voices) {
      if (voice.isUsEnglish && voice.isNatural) return voice;
    }
    for (final voice in voices) {
      if (voice.isUsEnglish) return voice;
    }
    return voices.first;
  }

  Future<void> applyVoice(EmoVoice voice) async {
    try {
      await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
      currentVoice = voice;
    } catch (_) {}
  }

  Future<void> previewVoice(EmoVoice voice) async {
    final previous = currentVoice;
    try {
      await _tts.stop();
      await _tts.setVoice({'name': voice.name, 'locale': voice.locale});
      await _tts.speak('Hi, I am Emo. This is how I sound.');
    } catch (_) {}
    if (previous != null) {
      try {
        await _tts.setVoice({
          'name': previous.name,
          'locale': previous.locale,
        });
      } catch (_) {}
    }
  }

  String _lastRecognized = '';
  bool _finalDispatched = false;

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
          if (!_finalDispatched && _lastRecognized.trim().isNotEmpty) {
            _finalDispatched = true;
            onFinal?.call(_lastRecognized.trim());
          } else {
            onError?.call(e.errorMsg);
          }
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
      if (!isListening && !_finalDispatched && _lastRecognized.trim().isNotEmpty) {
        _finalDispatched = true;
        final words = _lastRecognized.trim();
        onFinal?.call(words);
      }
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
    _lastRecognized = '';
    _finalDispatched = false;
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
          _lastRecognized = result.recognizedWords;
          onPartial?.call(result.recognizedWords);
          if (result.finalResult && !_finalDispatched) {
            _finalDispatched = true;
            onFinal?.call(result.recognizedWords);
          }
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: ListenMode.dictation,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 2),
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
    if (!_finalDispatched && _lastRecognized.trim().isNotEmpty) {
      _finalDispatched = true;
      onFinal?.call(_lastRecognized.trim());
    }
  }

  GoogleTtsService? googleTts;
  Future<bool> Function(Uint8List bytes)? onPlayAudio;
  Future<void> Function()? onStopAudio;
  bool isSpeaking = false;
  bool get speaking => isSpeaking;

  Future<void> speak(String text) async {
    if (!ttsEnabled || text.trim().isEmpty) return;
    isSpeaking = true;

    // 1. If Google Cloud TTS is enabled and configured, try cool Journey/Studio AI voice
    if (googleTts != null &&
        googleTts!.enabled &&
        googleTts!.configured &&
        onPlayAudio != null) {
      try {
        await stopPlayback();
        final bytes = await googleTts!.synthesize(text, rate: rate * 2.0);
        if (bytes != null && bytes.isNotEmpty) {
          final played = await onPlayAudio!(bytes);
          if (played) {
            isSpeaking = false;
            return;
          }
        }
      } catch (_) {}
    }

    // 2. Seamlessly fall back to on-device TTS
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
    isSpeaking = false;
  }

  Future<void> stopPlayback() async {
    try {
      await onStopAudio?.call();
    } catch (_) {}
    try {
      await _tts.stop();
    } catch (_) {}
    isSpeaking = false;
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
      await stopPlayback();
    }
  }
}
