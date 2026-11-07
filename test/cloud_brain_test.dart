import 'dart:convert';

import 'package:emo/models.dart';
import 'package:emo/services/cloud_brain.dart';
import 'package:emo/services/command_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

CloudBrain brainWith(MockClient client) {
  return CloudBrain(client: client)
    ..apiKey = 'test-key'
    ..endpoint = 'https://example.com/v1/chat/completions'
    ..model = 'test-model';
}

String chatBody(String content) => jsonEncode({
      'choices': [
        {
          'message': {'content': content},
        },
      ],
    });

void main() {
  group('CloudProvider presets', () {
    test('Gemini default model is a current, non-retired model', () {
      expect(CloudProvider.gemini.model, isNot('gemini-2.5-flash'));
      expect(CloudProvider.gemini.model, isNotEmpty);
      expect(CloudProvider.openrouter.model, isNot('google/gemini-2.5-flash'));
    });
  });

  group('CloudBrain', () {
    test('turns a paraphrase into a real device intent', () async {
      http.Request? sent;
      final brain = brainWith(MockClient((request) async {
        sent = request;
        return http.Response(
          chatBody('{"action":"brightness","value":35}'),
          200,
          headers: {'content-type': 'application/json'},
        );
      }));

      final reply = await brain.interpret(
        text: 'it is too bright in here, take it down a notch',
        device: const DeviceState(brightness: 0.8, volumeMusic: 0.4),
        routines: const [],
      );

      expect(reply.error, isNull);
      expect(reply.command?.kind, IntentKind.brightness);
      expect(reply.command?.value, closeTo(0.35, 0.001));
      expect(sent?.headers['Authorization'], 'Bearer test-key');
      expect(sent?.body, contains('brightness 80%'));
    });

    test('reads JSON wrapped in a code fence', () async {
      final brain = brainWith(MockClient((_) async => http.Response(
            chatBody('```json\n{"action":"chat","reply":"Paris."}\n```'),
            200,
          )));

      final reply = await brain.interpret(
        text: 'capital of France?',
        device: const DeviceState(),
        routines: const [],
      );

      expect(reply.chat, 'Paris.');
      expect(reply.command, isNull);
    });

    test('asks instead of guessing a missing routine', () async {
      final brain = brainWith(MockClient((_) async => http.Response(
            chatBody('{"action":"runRoutine","target":"Sleep"}'),
            200,
          )));

      final reply = await brain.interpret(
        text: 'run sleep mode',
        device: const DeviceState(),
        routines: const [
          Routine(
            id: 'wind-down',
            name: 'Wind down',
            iconKey: 'moon',
            enabled: true,
            trigger: 'time',
            time: '22:30',
            actions: [],
          ),
        ],
      );

      expect(reply.command, isNull);
      expect(reply.chat, contains('Wind down'));
    });

    test('reports a rejected key honestly', () async {
      final brain = brainWith(
        MockClient((_) async => http.Response('{"error":{}}', 401)),
      );

      final reply = await brain.interpret(
        text: 'hello',
        device: const DeviceState(),
        routines: const [],
      );

      expect(reply.command, isNull);
      expect(reply.chat, isNull);
      expect(reply.error, contains('rejected'));
    });

    test('surfaces the provider reason for a bad key', () async {
      final brain = brainWith(MockClient((_) async => http.Response(
            jsonEncode({
              'error': {
                'code': 400,
                'message': 'Please pass a valid API key',
                'status': 'INVALID_ARGUMENT',
              },
            }),
            400,
            headers: {'content-type': 'application/json'},
          )));

      final reply = await brain.interpret(
        text: 'hello',
        device: const DeviceState(),
        routines: const [],
      );

      expect(reply.error, contains('API key'));
      expect(reply.error, contains('valid API key'));
    });

    test('does not call the provider without a key', () async {
      var called = false;
      final brain = CloudBrain(client: MockClient((_) async {
        called = true;
        return http.Response(chatBody('{}'), 200);
      }));

      final reply = await brain.interpret(
        text: 'hello',
        device: const DeviceState(),
        routines: const [],
      );

      expect(reply.error, contains('API key'));
      expect(called, isFalse);
    });
  });

  group('CommandParser status questions', () {
    const device = DeviceState(wifiEnabled: true, wifiConnected: true);

    test('does not toggle Wi-Fi when asked about it', () {
      final parsed = CommandParser.parse('am I connected to wifi', device, const []);
      expect(parsed.kind, IntentKind.wifi);
      expect(parsed.mode, 'status');
      expect(parsed.on, isNull);
    });

    test('does not change volume when asked about it', () {
      final parsed = CommandParser.parse('what is the volume', device, const []);
      expect(parsed.kind, IntentKind.volume);
      expect(parsed.mode, 'status');
    });

    test('does not turn on Do Not Disturb when asked', () {
      final parsed = CommandParser.parse('is do not disturb on', device, const []);
      expect(parsed.kind, IntentKind.dnd);
      expect(parsed.mode, 'status');
    });

    test('still executes direct commands', () {
      final parsed = CommandParser.parse('turn on the torch', device, const []);
      expect(parsed.kind, IntentKind.torch);
      expect(parsed.on, isTrue);
      expect(parsed.mode, isNull);
    });
  });
}
