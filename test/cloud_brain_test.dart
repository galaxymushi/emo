import 'dart:convert';

import 'package:emo/models.dart';
import 'package:emo/services/cloud_brain.dart';
import 'package:emo/services/command_engine.dart';
import 'package:emo/services/memory_store.dart';
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

    test('migrates a saved retired model to the preset default', () {
      expect(
        CloudProvider.resolveModel(CloudProvider.gemini, 'gemini-2.5-flash'),
        CloudProvider.gemini.model,
      );
      expect(
        CloudProvider.resolveModel(
          CloudProvider.openrouter,
          'google/gemini-2.5-flash',
        ),
        CloudProvider.openrouter.model,
      );
      expect(
        CloudProvider.resolveModel(CloudProvider.gemini, null),
        CloudProvider.gemini.model,
      );
    });

    test('keeps a non-retired model and custom models', () {
      expect(
        CloudProvider.resolveModel(CloudProvider.gemini, 'gemini-3.5-flash'),
        'gemini-3.5-flash',
      );
      expect(
        CloudProvider.resolveModel(CloudProvider.custom, 'llama3'),
        'llama3',
      );
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
      expect(sent?.body, contains('"max_tokens":300'));
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

    test('retries once when the model is busy', () async {
      var calls = 0;
      final brain = brainWith(MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('{}', 503);
        return http.Response(
          chatBody('{"action":"chat","reply":"Hello."}'),
          200,
        );
      }));

      final reply = await brain.interpret(
        text: 'hi',
        device: const DeviceState(),
        routines: const [],
      );

      expect(calls, 2);
      expect(reply.chat, 'Hello.');
    });

    test('explains a persistently busy model', () async {
      final brain = brainWith(
        MockClient((_) async => http.Response('{}', 503)),
      );

      final reply = await brain.interpret(
        text: 'hi',
        device: const DeviceState(),
        routines: const [],
      );

      expect(reply.error, contains('busy'));
    });

    test('explains an out-of-credits account', () async {
      final brain = brainWith(
        MockClient((_) async => http.Response('{}', 402)),
      );

      final reply = await brain.interpret(
        text: 'hi',
        device: const DeviceState(),
        routines: const [],
      );

      expect(reply.error, contains('credits'));
    });

    test('surfaces the provider reason for a bad key', () async {      final brain = brainWith(MockClient((_) async => http.Response(
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

  group('Persona and memory', () {
    test('system prompt carries the boss name and remembered facts', () async {
      String? body;
      final brain = brainWith(MockClient((request) async {
        body = request.body;
        return http.Response(chatBody('{"action":"chat","reply":"Hello."}'), 200);
      }));
      final memory = MemoryStore();
      await memory.add('Likes tea');

      await brain.interpret(
        text: 'hello',
        device: const DeviceState(),
        routines: const [],
        owner: 'boss',
        memory: memory,
      );

      final decoded = jsonDecode(body!) as Map<String, dynamic>;
      final messages = decoded['messages'] as List;
      final system = (messages.first as Map)['content'] as String;
      expect(system, contains("Emo, boss's personal assistant"));
      expect(system, contains('Likes tea'));
      expect(system, contains('remember'));
    });

    test('remember action becomes a memory command', () async {
      final brain = brainWith(MockClient((request) async {
        return http.Response(
          chatBody('{"action":"remember","target":"Prefers dark mode"}'),
          200,
        );
      }));

      final reply = await brain.interpret(
        text: 'remember that I prefer dark mode',
        device: const DeviceState(),
        routines: const [],
      );

      expect(reply.command?.kind, IntentKind.remember);
      expect(reply.command?.target, 'Prefers dark mode');
    });

    test('empty balance is reported as missing credits', () async {
      final brain = brainWith(MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'message': 'You have no credits remaining.',
              'code': 'credit_balance_exhausted',
            },
          }),
          429,
        );
      }));

      final reply = await brain.interpret(
        text: 'hello',
        device: const DeviceState(),
        routines: const [],
      );

      expect(reply.error, contains('no credits'));
    });

    test('a daily free-tier limit is not reported as missing credits',
        () async {
      final brain = brainWith(MockClient((request) async {
        return http.Response(
          jsonEncode({
            'error': {
              'code': 429,
              'message': 'You exceeded your current quota, please check your '
                  'plan and billing details. Quota exceeded for metric: '
                  'generate_content_free_tier_requests, limit: 20, model: '
                  'gemini-3.8-flash, description: Generate content requests '
                  'per day limit exceeded on Free Tier. Please retry in '
                  '21h9m56s.',
              'status': 'RESOURCE_EXHAUSTED',
            },
          }),
          429,
        );
      }));

      final reply = await brain.interpret(
        text: 'hello',
        device: const DeviceState(),
        routines: const [],
      );

      expect(reply.error, contains('resets daily'));
      expect(reply.error, isNot(contains('no credits')));
    });
  });
}
