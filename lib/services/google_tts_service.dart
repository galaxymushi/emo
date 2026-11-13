import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class GoogleTtsVoice {
  const GoogleTtsVoice({
    required this.id,
    required this.name,
    required this.gender,
    required this.description,
    this.isGemini = false,
    this.geminiVoiceName = 'Puck',
  });

  final String id;
  final String name;
  final String gender;
  final String description;
  final bool isGemini;
  final String geminiVoiceName;

  /// Gemini AI Flagship Multimodal Voices (direct Google AI Studio key)
  static const puck = GoogleTtsVoice(
    id: 'gemini-puck',
    name: 'Gemini Puck',
    gender: 'Male',
    description: 'Curious, lively, expressive AI voice',
    isGemini: true,
    geminiVoiceName: 'Puck',
  );

  static const aoede = GoogleTtsVoice(
    id: 'gemini-aoede',
    name: 'Gemini Aoede',
    gender: 'Female',
    description: 'Warm, natural, conversational AI voice',
    isGemini: true,
    geminiVoiceName: 'Aoede',
  );

  static const charon = GoogleTtsVoice(
    id: 'gemini-charon',
    name: 'Gemini Charon',
    gender: 'Male',
    description: 'Calm, deep, confident AI voice',
    isGemini: true,
    geminiVoiceName: 'Charon',
  );

  static const fenrir = GoogleTtsVoice(
    id: 'gemini-fenrir',
    name: 'Gemini Fenrir',
    gender: 'Male',
    description: 'Crisp, articulate, modern AI voice',
    isGemini: true,
    geminiVoiceName: 'Fenrir',
  );

  static const kore = GoogleTtsVoice(
    id: 'gemini-kore',
    name: 'Gemini Kore',
    gender: 'Female',
    description: 'Soothing, friendly, clear AI voice',
    isGemini: true,
    geminiVoiceName: 'Kore',
  );

  /// Google Cloud Journey & Studio voices
  static const journeyF = GoogleTtsVoice(
    id: 'en-US-Journey-F',
    name: 'Journey Female',
    gender: 'Female',
    description: 'Expressive, futuristic assistant',
  );

  static const journeyD = GoogleTtsVoice(
    id: 'en-US-Journey-D',
    name: 'Journey Male',
    gender: 'Male',
    description: 'Smooth, modern assistant',
  );

  static const journeyO = GoogleTtsVoice(
    id: 'en-US-Journey-O',
    name: 'Journey Energetic',
    gender: 'Female',
    description: 'Engaging, lively, conversational',
  );

  static const studioO = GoogleTtsVoice(
    id: 'en-US-Studio-O',
    name: 'Studio Master',
    gender: 'Female',
    description: 'Ultra-high-fidelity studio clarity',
  );

  static const studioQ = GoogleTtsVoice(
    id: 'en-US-Studio-Q',
    name: 'Studio Deep',
    gender: 'Male',
    description: 'Rich, articulate studio voice',
  );

  static const all = [
    puck,
    aoede,
    charon,
    fenrir,
    kore,
    journeyF,
    journeyD,
    journeyO,
    studioO,
    studioQ,
  ];

  static GoogleTtsVoice byId(String id) {
    for (final v in all) {
      if (v.id == id) return v;
    }
    return puck;
  }
}

class GoogleTtsService {
  GoogleTtsService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String apiKey = '';
  GoogleTtsVoice voice = GoogleTtsVoice.puck;
  bool enabled = true;

  bool get configured => apiKey.trim().isNotEmpty;

  /// Synthesizes [text] using Google AI or Google Cloud TTS.
  /// Returns playable audio bytes (WAV or MP3) or null on failure.
  Future<Uint8List?> synthesize(
    String text, {
    double rate = 1.0,
    double pitch = 0.0,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty || text.trim().isEmpty) return null;

    final isAiStudioKey = key.startsWith('AQ.') || key.startsWith('AIza');

    if (isAiStudioKey || voice.isGemini) {
      final geminiAudio = await _synthesizeGemini(text.trim(), key);
      if (geminiAudio != null) return geminiAudio;
      if (!isAiStudioKey) {
        return _synthesizeCloud(text.trim(), key, rate: rate, pitch: pitch);
      }
      return null;
    } else {
      final cloudAudio =
          await _synthesizeCloud(text.trim(), key, rate: rate, pitch: pitch);
      if (cloudAudio != null) return cloudAudio;
      return _synthesizeGemini(text.trim(), key);
    }
  }

  Future<Uint8List?> _synthesizeGemini(String text, String key) async {
    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=$key',
    );

    final voiceName = voice.isGemini ? voice.geminiVoiceName : 'Puck';

    final payload = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': text}
          ]
        }
      ],
      'generationConfig': {
        'responseModalities': ['AUDIO'],
        'speechConfig': {
          'voiceConfig': {
            'prebuiltVoiceConfig': {
              'voiceName': voiceName,
            }
          }
        }
      }
    });

    try {
      final response = await _client
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            body: payload,
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return null;

      final dynamic data = jsonDecode(response.body);
      if (data is Map && data['candidates'] is List) {
        final candidates = data['candidates'] as List;
        if (candidates.isNotEmpty) {
          final first = candidates.first as Map;
          final content = first['content'] as Map?;
          final parts = content?['parts'] as List?;
          if (parts != null && parts.isNotEmpty) {
            final part = parts.first as Map;
            final inlineData = part['inlineData'] as Map?;
            final b64 = inlineData?['data'] as String?;
            if (b64 != null && b64.isNotEmpty) {
              final pcm = base64Decode(b64);
              return _pcmToWav(pcm, sampleRate: 24000, channels: 1);
            }
          }
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<Uint8List?> _synthesizeCloud(
    String text,
    String key, {
    double rate = 1.0,
    double pitch = 0.0,
  }) async {
    final url = Uri.parse(
      'https://texttospeech.googleapis.com/v1/text:synthesize?key=$key',
    );

    final payload = jsonEncode({
      'input': {'text': text},
      'voice': {
        'languageCode': 'en-US',
        'name': voice.id,
      },
      'audioConfig': {
        'audioEncoding': 'MP3',
        'speakingRate': rate.clamp(0.5, 2.0),
        'pitch': pitch.clamp(-10.0, 10.0),
      },
    });

    try {
      final response = await _client
          .post(
            url,
            headers: {
              'Content-Type': 'application/json; charset=utf-8',
              'User-Agent': 'Emo-Android-GoogleTTS',
            },
            body: payload,
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) return null;

      final dynamic data = jsonDecode(response.body);
      if (data is Map && data['audioContent'] is String) {
        return base64Decode(data['audioContent'] as String);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  /// Converts 16-bit little-endian PCM to a standard WAV audio format.
  Uint8List _pcmToWav(Uint8List pcm, {int sampleRate = 24000, int channels = 1}) {
    final header = Uint8List(44);
    final b = ByteData.view(header.buffer);

    header.setRange(0, 4, utf8.encode('RIFF'));
    b.setUint32(4, 36 + pcm.length, Endian.little);
    header.setRange(8, 12, utf8.encode('WAVE'));
    header.setRange(12, 16, utf8.encode('fmt '));
    b.setUint32(16, 16, Endian.little);
    b.setUint16(20, 1, Endian.little); // PCM
    b.setUint16(22, channels, Endian.little);
    b.setUint32(24, sampleRate, Endian.little);
    b.setUint32(28, sampleRate * channels * 2, Endian.little);
    b.setUint16(32, channels * 2, Endian.little);
    b.setUint16(34, 16, Endian.little);
    header.setRange(36, 40, utf8.encode('data'));
    b.setUint32(40, pcm.length, Endian.little);

    final full = Uint8List(header.length + pcm.length);
    full.setAll(0, header);
    full.setAll(header.length, pcm);
    return full;
  }

  void close() => _client.close();
}
