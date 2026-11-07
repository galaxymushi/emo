import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models.dart';
import 'command_engine.dart';

class CloudProvider {
  const CloudProvider({
    required this.id,
    required this.name,
    required this.endpoint,
    required this.model,
    required this.keyUrl,
    this.isCustom = false,
  });

  final String id;
  final String name;
  final String endpoint;
  final String model;
  final String keyUrl;
  final bool isCustom;

  static const gemini = CloudProvider(
    id: 'gemini',
    name: 'Google Gemini',
    endpoint:
        'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions',
    model: 'gemini-2.5-flash',
    keyUrl: 'https://aistudio.google.com/app/apikey',
  );

  static const openai = CloudProvider(
    id: 'openai',
    name: 'OpenAI',
    endpoint: 'https://api.openai.com/v1/chat/completions',
    model: 'gpt-4o-mini',
    keyUrl: 'https://platform.openai.com/api-keys',
  );

  static const openrouter = CloudProvider(
    id: 'openrouter',
    name: 'OpenRouter',
    endpoint: 'https://openrouter.ai/api/v1/chat/completions',
    model: 'google/gemini-2.5-flash',
    keyUrl: 'https://openrouter.ai/keys',
  );

  static const groq = CloudProvider(
    id: 'groq',
    name: 'Groq',
    endpoint: 'https://api.groq.com/openai/v1/chat/completions',
    model: 'llama-3.3-70b-versatile',
    keyUrl: 'https://console.groq.com/keys',
  );

  static const custom = CloudProvider(
    id: 'custom',
    name: 'Custom',
    endpoint: '',
    model: '',
    keyUrl: '',
    isCustom: true,
  );

  static const all = [gemini, openai, openrouter, groq, custom];

  static CloudProvider byId(String id) {
    for (final provider in all) {
      if (provider.id == id) return provider;
    }
    return gemini;
  }
}

class CloudReply {
  const CloudReply.action(this.command, this.actionName)
      : chat = null,
        error = null;

  const CloudReply.chat(this.chat)
      : command = null,
        actionName = null,
        error = null;

  const CloudReply.failure(this.error)
      : command = null,
        actionName = null,
        chat = null;

  final ParsedCommand? command;
  final String? actionName;
  final String? chat;
  final String? error;

  bool get ok => error == null;
}

class CloudBrain {
  CloudBrain({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String apiKey = '';
  String endpoint = CloudProvider.gemini.endpoint;
  String model = CloudProvider.gemini.model;

  bool get configured =>
      apiKey.trim().isNotEmpty &&
      endpoint.trim().isNotEmpty &&
      model.trim().isNotEmpty;

  void close() => _client.close();

  Future<CloudReply> interpret({
    required String text,
    required DeviceState device,
    required List<Routine> routines,
    List<Map<String, String>> history = const [],
  }) async {
    if (!configured) {
      return const CloudReply.failure(
        'Cloud AI has no API key. Add one in Settings.',
      );
    }
    final result = await _chat([
      {'role': 'system', 'content': _systemPrompt(device, routines)},
      ...history,
      {'role': 'user', 'content': text},
    ]);
    if (result.error != null) return CloudReply.failure(result.error);

    final map = _extractJson(result.text ?? '');
    if (map == null) {
      return const CloudReply.failure(
        'Cloud AI sent a reply Emo could not read.',
      );
    }

    final action = (map['action'] as String? ?? 'chat')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '');
    if (action == 'chat' || action == 'answer' || action == 'reply') {
      final reply = (map['reply'] as String? ?? '').trim();
      if (reply.isEmpty) {
        return const CloudReply.failure('Cloud AI did not return an answer.');
      }
      return CloudReply.chat(_flatten(reply));
    }

    return _toCommand(action, map, device, routines, text);
  }

  /// Returns null when the provider accepted the request, otherwise a message.
  Future<String?> testConnection() async {
    if (!configured) return 'Add an API key first.';
    final result = await _chat([
      {
        'role': 'user',
        'content': 'Reply with exactly one word: ready',
      },
    ], temperature: 0);
    return result.error;
  }

  Future<({String? text, String? error})> _chat(
    List<Map<String, String>> messages, {
    double temperature = 0.2,
  }) async {
    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${apiKey.trim()}',
            },
            body: jsonEncode({
              'model': model.trim(),
              'messages': messages,
              'temperature': temperature,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } on TimeoutException {
      return (
        text: null,
        error: 'The cloud took too long to answer. Check your connection.',
      );
    } on http.ClientException {
      return (
        text: null,
        error: 'Could not reach the cloud. Check your internet connection.',
      );
    } catch (_) {
      return (
        text: null,
        error: 'Could not reach the cloud. Check your internet connection.',
      );
    }

    if (response.statusCode == 400 ||
        response.statusCode == 401 ||
        response.statusCode == 403) {
      final detail = _errorDetail(response.body);
      final keyIssue = response.statusCode == 401 ||
          response.statusCode == 403 ||
          (detail?.toLowerCase().contains('api key') ?? false);
      if (keyIssue) {
        return (
          text: null,
          error: detail == null
              ? 'The API key was rejected. Check it in Settings.'
              : 'The API key was rejected: $detail',
        );
      }
      return (
        text: null,
        error: detail ?? 'The provider rejected the request (HTTP 400).',
      );
    }
    if (response.statusCode == 404) {
      return (
        text: null,
        error: 'That model or endpoint was not found. Check the model name.',
      );
    }
    if (response.statusCode == 429) {
      return (
        text: null,
        error: 'The AI provider is rate-limiting requests. Try again shortly.',
      );
    }
    if (response.statusCode != 200) {
      return (
        text: null,
        error: 'The AI provider returned an error (HTTP ${response.statusCode}).',
      );
    }

    try {
      final decoded = jsonDecode(response.body);
      final choices = decoded is Map ? decoded['choices'] : null;
      final first = choices is List && choices.isNotEmpty ? choices.first : null;
      final message = first is Map ? first['message'] : null;
      final content = message is Map ? message['content'] : null;
      if (content is String && content.trim().isNotEmpty) {
        return (text: content, error: null);
      }
      if (content is List) {
        final joined = content
            .whereType<Map>()
            .map((part) => part['text'])
            .whereType<String>()
            .join()
            .trim();
        if (joined.isNotEmpty) return (text: joined, error: null);
      }
    } catch (_) {}
    return (text: null, error: 'Cloud AI sent an empty answer.');
  }

  String? _errorDetail(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final error = decoded['error'];
        if (error is Map) {
          final message = error['message'];
          if (message is String && message.trim().isNotEmpty) {
            final clean = _flatten(message);
            return clean.length > 140 ? clean.substring(0, 140) : clean;
          }
        }
        if (error is String && error.trim().isNotEmpty) {
          return _flatten(error);
        }
      }
    } catch (_) {}
    return null;
  }

  Map<String, dynamic>? _extractJson(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '')
          .replaceFirst(RegExp(r'\s*```$'), '');
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    try {
      final decoded = jsonDecode(text.substring(start, end + 1));
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  CloudReply _toCommand(
    String action,
    Map<String, dynamic> map,
    DeviceState device,
    List<Routine> routines,
    String raw,
  ) {
    final on = map['on'] is bool ? map['on'] as bool : null;
    final target = _clean(map['target'], 80);
    final body = _clean(map['body'] ?? map['message'], 320);
    final mode = _clean(map['mode'], 24)?.toLowerCase();
    final percent = map['value'] is num
        ? ((map['value'] as num).toDouble()).clamp(0, 100) / 100
        : null;

    ParsedCommand command(IntentKind kind) =>
        ParsedCommand(kind: kind, raw: raw);

    CloudReply ask(String question) => CloudReply.chat(question);

    switch (action) {
      case 'torch':
      case 'flashlight':
        return CloudReply.action(
          ParsedCommand(kind: IntentKind.torch, raw: raw, on: on),
          'torch',
        );
      case 'wifi':
      case 'wi-fi':
        return CloudReply.action(
          ParsedCommand(kind: IntentKind.wifi, raw: raw, on: on),
          'Wi-Fi',
        );
      case 'bluetooth':
        return CloudReply.action(
          ParsedCommand(kind: IntentKind.bluetooth, raw: raw, on: on),
          'Bluetooth',
        );
      case 'dnd':
      case 'donotdisturb':
        final dndMode = ['off', 'priority', 'none'].contains(mode)
            ? mode!
            : 'none';
        return CloudReply.action(
          ParsedCommand(kind: IntentKind.dnd, raw: raw, mode: dndMode),
          'Do Not Disturb',
        );
      case 'brightness':
        return CloudReply.action(
          ParsedCommand(
            kind: IntentKind.brightness,
            raw: raw,
            value: percent ?? 0.5,
            mode: percent == null ? 'relative' : 'absolute',
          ),
          'brightness',
        );
      case 'volume':
        final stream = ['music', 'ring', 'alarm'].contains(mode) ? mode! : 'music';
        return CloudReply.action(
          ParsedCommand(
            kind: IntentKind.volume,
            raw: raw,
            value: percent ?? 0.5,
            mode: stream,
          ),
          '$stream volume',
        );
      case 'openapp':
      case 'launchapp':
        if (target == null) return ask('Which app should I open?');
        return CloudReply.action(
          ParsedCommand(kind: IntentKind.openApp, raw: raw, target: target),
          'opening $target',
        );
      case 'call':
      case 'dial':
        if (target == null) return ask('Who should I call?');
        return CloudReply.action(
          ParsedCommand(kind: IntentKind.call, raw: raw, target: target),
          'calling $target',
        );
      case 'message':
      case 'sms':
      case 'sendmessage':
        if (target == null) return ask('Who should I message?');
        return CloudReply.action(
          ParsedCommand(
            kind: IntentKind.message,
            raw: raw,
            target: target,
            body: body,
          ),
          'messaging $target',
        );
      case 'settings':
        const settingsModes = {
          'wifi',
          'bluetooth',
          'display',
          'sound',
          'battery',
          'location',
          'airplane',
          'accessibility',
          'notification_access',
          'data',
          'apps',
          'developer',
          'settings',
        };
        final settingsMode =
            settingsModes.contains(mode) ? mode! : 'settings';
        return CloudReply.action(
          ParsedCommand(
            kind: IntentKind.settings,
            raw: raw,
            mode: settingsMode,
          ),
          '$settingsMode settings',
        );
      case 'battery':
        return CloudReply.action(command(IntentKind.battery), 'battery');
      case 'notifications':
        return CloudReply.action(
          ParsedCommand(
            kind: IntentKind.notifications,
            raw: raw,
            mode: mode == 'shade' ? 'shade' : 'list',
          ),
          'notifications',
        );
      case 'clearnotifications':
        return CloudReply.action(
          command(IntentKind.clearNotifications),
          'clearing notifications',
        );
      case 'back':
        return CloudReply.action(command(IntentKind.back), 'back');
      case 'home':
        return CloudReply.action(command(IntentKind.home), 'home');
      case 'recents':
        return CloudReply.action(command(IntentKind.recents), 'recent apps');
      case 'notificationshade':
        return CloudReply.action(
          command(IntentKind.notificationShade),
          'notification shade',
        );
      case 'quicksettings':
        return CloudReply.action(
          command(IntentKind.quickSettings),
          'quick settings',
        );
      case 'lock':
        return CloudReply.action(command(IntentKind.lock), 'lock');
      case 'screenshot':
        return CloudReply.action(command(IntentKind.screenshot), 'screenshot');
      case 'swipeup':
        return CloudReply.action(
          ParsedCommand(kind: IntentKind.swipeUp, raw: raw, mode: 'up'),
          'scrolling down',
        );
      case 'swipedown':
        return CloudReply.action(
          ParsedCommand(kind: IntentKind.swipeDown, raw: raw, mode: 'down'),
          'scrolling up',
        );
      case 'search':
        if (target == null) return ask('What should I search for?');
        return CloudReply.action(
          ParsedCommand(kind: IntentKind.search, raw: raw, target: target),
          'search',
        );
      case 'runroutine':
        if (target == null) return ask('Which routine should I run?');
        for (final routine in routines) {
          if (routine.name.toLowerCase() == target.toLowerCase()) {
            return CloudReply.action(
              ParsedCommand(
                kind: IntentKind.runRoutine,
                raw: raw,
                routine: routine,
              ),
              routine.name,
            );
          }
        }
        final names = routines.map((r) => r.name).join(', ');
        return ask(
          names.isEmpty
              ? "You don't have any routines yet."
              : 'I could not find a routine called $target. You have: $names.',
        );
      case 'help':
        return CloudReply.action(command(IntentKind.help), 'help');
      default:
        final reply = (map['reply'] as String? ?? '').trim();
        if (reply.isNotEmpty) return CloudReply.chat(_flatten(reply));
        return const CloudReply.failure(
          'Cloud AI suggested something Emo cannot do.',
        );
    }
  }

  String _systemPrompt(DeviceState device, List<Routine> routines) {
    final routinesList = routines.isEmpty
        ? 'none'
        : routines.map((r) => '${r.name} (${r.triggerLabel})').join(', ');
    return '''
You are the language layer of Emo, an Android assistant. The app executes commands; you never perform them and never claim they already happened.
Reply with one JSON object only, no markdown:
{"action": "...", "on": true, "target": "...", "body": "...", "value": 40, "mode": "...", "reply": "..."}

Actions and fields:
- torch, wifi, bluetooth: "on" true or false.
- dnd: mode "none" (on), "priority", or "off".
- brightness, volume: "value" is 0-100 percent. volume mode "music" | "ring" | "alarm".
- openApp: target is the app name.
- call: target is a contact name or number.
- message: target is a contact name or number, "body" is optional text.
- settings: mode wifi | bluetooth | display | sound | battery | location | airplane | accessibility | notification_access | data | apps | developer | settings.
- battery, notifications (mode "list" or "shade"), clearNotifications.
- back, home, recents, notificationShade, quickSettings, lock, screenshot, swipeUp (scroll down), swipeDown (scroll up).
- search: target is the query.
- runRoutine: target is an exact routine name.
- help.
- chat: questions, conversation, or clarification. Put the answer in "reply", under 45 words.

Rules:
- Never claim an action already happened; describe no results.
- Plain text in "reply": no markdown, no emoji.
- Use "chat" for anything that is not a phone action.
- If a phone action is ambiguous, use "chat" and ask one short question.
- For relative requests (brighter, quieter), choose a sensible value from the current state.

Phone now: battery ${device.battery}%${device.charging ? ' charging' : ''}; torch ${device.torchOn ? 'on' : 'off'}; Wi-Fi ${device.wifiEnabled ? 'on' : 'off'}; Bluetooth ${device.bluetoothOn ? 'on' : 'off'}; Do Not Disturb ${device.dndLabel}; brightness ${(device.brightness * 100).round()}%; media volume ${(device.volumeMusic * 100).round()}%; ringer ${(device.volumeRing * 100).round()}%.
Routines: $routinesList.
''';
  }

  String? _clean(dynamic value, int max) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length > max ? trimmed.substring(0, max) : trimmed;
  }

  String _flatten(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
