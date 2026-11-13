import 'dart:convert';
import 'dart:typed_data';

import 'package:emo/services/google_tts_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('GoogleTtsService', () {
    test('synthesize with Journey voice returns audio bytes when API succeeds',
        () async {
      final fakeBytes = [1, 2, 3, 4, 5];
      final fakeBase64 = base64Encode(fakeBytes);

      final client = MockClient((request) async {
        expect(request.url.queryParameters['key'], 'test-api-key');
        expect(request.headers['Content-Type'], contains('application/json'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['input']['text'], 'Hello Emo');
        expect(body['voice']['name'], 'en-US-Journey-F');
        return http.Response(
          jsonEncode({'audioContent': fakeBase64}),
          200,
        );
      });

      final service = GoogleTtsService(client: client)
        ..apiKey = 'test-api-key'
        ..voice = GoogleTtsVoice.journeyF;

      final result = await service.synthesize('Hello Emo');
      expect(result, isNotNull);
      expect(result, equals(fakeBytes));
    });

    test('synthesize with Gemini AI voice generates valid WAV', () async {
      final fakePcm = Uint8List(100);
      final fakeBase64 = base64Encode(fakePcm);

      final client = MockClient((request) async {
        expect(request.url.toString(), contains('gemini-2.5-flash-preview-tts'));
        expect(request.url.queryParameters['key'], 'test-api-key');
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {
                      'inlineData': {
                        'mimeType': 'audio/L16;codec=pcm;rate=24000',
                        'data': fakeBase64,
                      }
                    }
                  ]
                }
              }
            ]
          }),
          200,
        );
      });

      final service = GoogleTtsService(client: client)
        ..apiKey = 'test-api-key'
        ..voice = GoogleTtsVoice.puck;

      final result = await service.synthesize('Hello Emo');
      expect(result, isNotNull);
      expect(result!.length, equals(44 + 100)); // 44-byte WAV header + 100-byte PCM
      expect(ascii.decode(result.sublist(0, 4)), 'RIFF');
      expect(ascii.decode(result.sublist(8, 12)), 'WAVE');
    });

    test('returns null when API key is empty', () async {
      final client = MockClient((_) async => http.Response('{}', 200));
      final service = GoogleTtsService(client: client)..apiKey = '';
      final result = await service.synthesize('Hello Emo');
      expect(result, isNull);
    });

    test('returns null when API returns error status', () async {
      final client = MockClient((_) async => http.Response('Error', 400));
      final service = GoogleTtsService(client: client)..apiKey = 'bad-key';
      final result = await service.synthesize('Hello Emo');
      expect(result, isNull);
    });

    test('GoogleTtsVoice byId resolves properly', () {
      expect(GoogleTtsVoice.byId('en-US-Journey-D').name, 'Journey Male');
      expect(GoogleTtsVoice.byId('gemini-puck').name, 'Gemini Puck');
      expect(GoogleTtsVoice.byId('nonexistent').id, GoogleTtsVoice.puck.id);
    });
  });
}
