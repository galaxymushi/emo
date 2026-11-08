import 'dart:convert';

import '../models.dart';
import 'command_engine.dart';
import 'memory_store.dart';
import 'persona.dart';

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

/// The single JSON contract shared by every language model Emo talks to.
/// The model only proposes an action; the app still performs it.
class IntentContract {
  const IntentContract._();

  static String systemPrompt({
    required DeviceState device,
    required List<Routine> routines,
    required String owner,
    required MemoryStore memory,
  }) {
    final routinesList = routines.isEmpty
        ? 'none'
        : routines.map((r) => '${r.name} (${r.triggerLabel})').join(', ');
    return '''
${Persona.systemPreamble(owner: owner, memory: memory)}
You are also the language layer of Emo on this Android phone. The app executes commands; you never perform them and never claim they already happened.
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
- remember: target is one short fact to keep about $owner, written plainly.
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

  /// Turns raw model output into a command or a chat answer.
  static CloudReply parse(
    String raw, {
    required DeviceState device,
    required List<Routine> routines,
    required String rawText,
    String source = 'Cloud AI',
  }) {
    final map = extractJson(raw);
    if (map == null) {
      return CloudReply.failure('$source sent a reply Emo could not read.');
    }

    final action = (map['action'] as String? ?? 'chat')
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s-]+'), '');
    if (action == 'chat' || action == 'answer' || action == 'reply') {
      final reply = (map['reply'] as String? ?? '').trim();
      if (reply.isEmpty) {
        return CloudReply.failure('$source did not return an answer.');
      }
      return CloudReply.chat(_flatten(reply));
    }

    return _toCommand(action, map, device, routines, rawText, source);
  }

  static Map<String, dynamic>? extractJson(String raw) {
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

  static CloudReply _toCommand(
    String action,
    Map<String, dynamic> map,
    DeviceState device,
    List<Routine> routines,
    String raw,
    String source,
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
        final stream =
            ['music', 'ring', 'alarm'].contains(mode) ? mode! : 'music';
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
      case 'remember':
      case 'note':
        if (target == null) return ask('What should I remember?');
        return CloudReply.action(
          ParsedCommand(kind: IntentKind.remember, raw: raw, target: target),
          'remembering that',
        );
      case 'help':
        return CloudReply.action(command(IntentKind.help), 'help');
      default:
        final reply = (map['reply'] as String? ?? '').trim();
        if (reply.isNotEmpty) return CloudReply.chat(_flatten(reply));
        return CloudReply.failure('$source suggested something Emo cannot do.');
    }
  }

  static String? _clean(dynamic value, int max) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length > max ? trimmed.substring(0, max) : trimmed;
  }

  static String _flatten(String value) =>
      value.replaceAll(RegExp(r'\s+'), ' ').trim();
}
