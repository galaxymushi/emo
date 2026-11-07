import '../models.dart';

enum IntentKind {
  torch,
  wifi,
  bluetooth,
  dnd,
  brightness,
  volume,
  openApp,
  call,
  message,
  settings,
  battery,
  notifications,
  clearNotifications,
  back,
  home,
  recents,
  notificationShade,
  quickSettings,
  lock,
  screenshot,
  swipeUp,
  swipeDown,
  search,
  runRoutine,
  help,
  unknown,
}

class ParsedCommand {
  const ParsedCommand({
    required this.kind,
    required this.raw,
    this.on,
    this.target,
    this.body,
    this.mode,
    this.value,
    this.routine,
  });

  final IntentKind kind;
  final String raw;
  final bool? on;
  final String? target;
  final String? body;
  final String? mode;
  final double? value;
  final Routine? routine;
}

class CommandParser {
  static final _on = RegExp(r'\b(on|enable|start|activate|turn on|switch on|power on)\b');
  static final _off =
      RegExp(r'\b(off|disable|stop|deactivate|turn off|switch off|kill|power off)\b');
  static final _number = RegExp(r'(\d{1,3})\s*(%|percent)?');

  static ParsedCommand parse(
    String raw,
    DeviceState device,
    List<Routine> routines,
  ) {
    final text = raw.trim();
    final lower = text.toLowerCase();
    bool has(String word) =>
        RegExp('\\b${RegExp.escape(word)}\\b').hasMatch(lower);
    bool hasAny(List<String> words) => words.any(has);
    final asksAboutState = RegExp(
      r'^(what|how|is|are|am|do|does|did|check|show|tell me)\b',
    ).hasMatch(lower);
    final hasActionVerb = RegExp(
      r'\b(turn|switch|enable|disable|activate|deactivate|start|stop|kill|power)\b',
    ).hasMatch(lower);

    if (text.isEmpty) {
      return ParsedCommand(kind: IntentKind.unknown, raw: text);
    }

    if (RegExp(r'^(hi|hey|hello|yo|hiya|good (morning|afternoon|evening))\b')
        .hasMatch(lower)) {
      return ParsedCommand(kind: IntentKind.help, raw: text, mode: 'greeting');
    }

    if (lower.contains('what can you do') ||
        lower == 'help' ||
        lower.contains('list commands') ||
        lower.contains('your commands')) {
      return ParsedCommand(kind: IntentKind.help, raw: text);
    }

    // Run a saved routine by name.
    for (final routine in routines) {
      final name = routine.name.toLowerCase();
      if (name.isNotEmpty &&
          lower.contains(name) &&
          (hasAny(['run', 'start', 'activate', 'do']) || lower.trim() == name)) {
        return ParsedCommand(
          kind: IntentKind.runRoutine,
          raw: text,
          routine: routine,
        );
      }
    }

    if (lower.contains('clear') &&
        (lower.contains('notification') || lower.contains('notifications'))) {
      return ParsedCommand(kind: IntentKind.clearNotifications, raw: text);
    }

    // Settings pages first so "open Wi-Fi settings" is not an app launch.
    if (lower.contains('setting') || lower.contains('panel')) {
      final kind = _settingsKind(lower);
      return ParsedCommand(kind: IntentKind.settings, raw: text, mode: kind);
    }

    if (hasAny(['lock the phone', 'lock phone', 'lock screen', 'lock the screen', 'lock my phone'])) {
      return ParsedCommand(kind: IntentKind.lock, raw: text);
    }

    if (lower.contains('screenshot') || lower.contains('screen shot')) {
      return ParsedCommand(kind: IntentKind.screenshot, raw: text);
    }

    if (lower.contains('scroll down') || lower.contains('swipe up to scroll')) {
      return ParsedCommand(kind: IntentKind.swipeUp, raw: text, mode: 'up');
    }
    if (lower.contains('scroll up') || lower.contains('swipe down to scroll')) {
      return ParsedCommand(kind: IntentKind.swipeDown, raw: text, mode: 'down');
    }

    if (RegExp(r'\b(go back|back|previous screen)\b').hasMatch(lower) &&
        lower.length < 30) {
      return ParsedCommand(kind: IntentKind.back, raw: text);
    }
    if (hasAny(['go home', 'home screen', 'back home', 'go to home'])) {
      return ParsedCommand(kind: IntentKind.home, raw: text);
    }
    if (hasAny(['recent apps', 'recents', 'app switcher', 'recent screens'])) {
      return ParsedCommand(kind: IntentKind.recents, raw: text);
    }
    if (hasAny(['quick settings', 'control panel', 'notification panel'])) {
      return ParsedCommand(kind: IntentKind.quickSettings, raw: text);
    }
    if (hasAny(['notification shade', 'open notifications', 'show notifications', 'pull down notifications'])) {
      return ParsedCommand(kind: IntentKind.notificationShade, raw: text);
    }

    final callMatch = RegExp(
      r'^(?:call|dial|phone|ring)\s+(?:up\s+)?(.+)$',
    ).firstMatch(lower);
    if (callMatch != null) {
      final target = callMatch.group(1)?.trim() ?? '';
      if (target.isNotEmpty) {
        return ParsedCommand(kind: IntentKind.call, raw: text, target: target);
      }
    }
    final callTo = RegExp(r'make a call to\s+(.+)').firstMatch(lower);
    if (callTo != null) {
      return ParsedCommand(
        kind: IntentKind.call,
        raw: text,
        target: callTo.group(1)?.trim() ?? '',
      );
    }

    final msgMatch = RegExp(
      r'^(?:text|message|sms|send (?:a )?(?:text|message)|send)\s+(?:to\s+)?(.+)$',
    ).firstMatch(text);
    if (msgMatch != null && !lower.startsWith('send feedback')) {
      var rest = msgMatch.group(1)?.trim() ?? '';
      String? body;
      final split = RegExp(
        r'\s+(?:saying|that|about|with the message)\s+',
        caseSensitive: false,
      ).firstMatch(rest);
      if (split != null) {
        body = rest.substring(split.end).trim();
        rest = rest.substring(0, split.start).trim();
      }
      rest = rest.replaceFirst(RegExp(r'^(a|an|the)\s+', caseSensitive: false), '');
      if (rest.isNotEmpty) {
        return ParsedCommand(
          kind: IntentKind.message,
          raw: text,
          target: rest,
          body: body,
        );
      }
    }

    if (hasAny(['torch', 'flashlight', 'flash light', 'flash'])) {
      final on = _off.hasMatch(lower) ? false : (_on.hasMatch(lower) ? true : null);
      if (asksAboutState && !hasActionVerb) {
        return ParsedCommand(kind: IntentKind.torch, raw: text, mode: 'status');
      }
      return ParsedCommand(kind: IntentKind.torch, raw: text, on: on);
    }

    if (hasAny(['wi-fi', 'wifi', 'wlan', 'wireless'])) {
      final on = _off.hasMatch(lower) ? false : (_on.hasMatch(lower) ? true : null);
      if (asksAboutState && !hasActionVerb) {
        return ParsedCommand(kind: IntentKind.wifi, raw: text, mode: 'status');
      }
      return ParsedCommand(kind: IntentKind.wifi, raw: text, on: on);
    }

    if (hasAny(['bluetooth', 'bt', 'headphones'])) {
      final on = _off.hasMatch(lower) ? false : (_on.hasMatch(lower) ? true : null);
      if (asksAboutState && !hasActionVerb) {
        return ParsedCommand(kind: IntentKind.bluetooth, raw: text, mode: 'status');
      }
      return ParsedCommand(kind: IntentKind.bluetooth, raw: text, on: on);
    }

    if (hasAny(['do not disturb', 'dnd', 'silent mode', 'mute notifications', 'focus mode'])) {
      if (asksAboutState && !hasActionVerb && !lower.contains('priority')) {
        return ParsedCommand(kind: IntentKind.dnd, raw: text, mode: 'status');
      }
      final mode = lower.contains('priority')
          ? 'priority'
          : (_off.hasMatch(lower) ? 'off' : 'none');
      return ParsedCommand(kind: IntentKind.dnd, raw: text, mode: mode);
    }

    if (lower.contains('brightness') ||
        hasAny(['dim the screen', 'dim screen', 'brighter', 'darker', 'screen light'])) {
      double? value;
      final match = _number.firstMatch(lower);
      if (match != null) {
        final parsed = int.tryParse(match.group(1) ?? '');
        if (parsed != null && parsed <= 100) {
          value = parsed / 100;
        }
      }
      if (value == null &&
          asksAboutState &&
          !hasAny(['brighter', 'darker', 'dim', 'increase', 'decrease'])) {
        return ParsedCommand(kind: IntentKind.brightness, raw: text, mode: 'status');
      }
      if (value == null) {
        if (hasAny(['brighter', 'increase', 'up'])) {
          value = clamp01(device.brightness + 0.2);
        } else if (hasAny(['darker', 'dim', 'decrease', 'down', 'low'])) {
          value = clamp01(device.brightness - 0.2);
        }
      }
      return ParsedCommand(
        kind: IntentKind.brightness,
        raw: text,
        value: value ?? 0.5,
        mode: value == null ? 'relative' : 'absolute',
      );
    }

    if (hasAny(['volume', 'sound', 'louder', 'quieter', 'mute', 'unmute', 'audio'])) {
      final stream = lower.contains('ring')
          ? 'ring'
          : lower.contains('alarm')
              ? 'alarm'
              : 'music';
      double? value;
      final match = _number.firstMatch(lower);
      if (match != null) {
        final parsed = int.tryParse(match.group(1) ?? '');
        if (parsed != null && parsed <= 100) value = parsed / 100;
      }
      if (value == null &&
          asksAboutState &&
          !hasAny(['louder', 'quieter', 'mute', 'unmute', 'increase', 'decrease', 'max'])) {
        return ParsedCommand(kind: IntentKind.volume, raw: text, mode: 'status');
      }
      if (value == null) {
        if (lower.contains('mute') && !lower.contains('unmute')) {
          value = 0;
        } else if (lower.contains('unmute')) {
          value = 0.45;
        } else if (hasAny(['louder', 'up', 'increase', 'max'])) {
          value = clamp01(device.volumeMusic + 0.25);
        } else if (hasAny(['quieter', 'down', 'decrease', 'lower'])) {
          value = clamp01(device.volumeMusic - 0.25);
        }
      }
      return ParsedCommand(
        kind: IntentKind.volume,
        raw: text,
        value: value ?? 0.5,
        mode: stream,
      );
    }

    if (lower.contains('battery') || lower.contains('charge level')) {
      return ParsedCommand(kind: IntentKind.battery, raw: text);
    }

    if (lower.contains('notification')) {
      return ParsedCommand(
        kind: IntentKind.notifications,
        raw: text,
        mode: hasAny(['read', 'check', 'what', 'any', 'list']) ? 'list' : 'shade',
      );
    }

    final search = RegExp(r'^(?:search|google|look up|find)\s+(?:for\s+|online\s+)?(.+)$')
        .firstMatch(text);
    if (search != null) {
      final query = search.group(1)?.trim() ?? '';
      if (query.isNotEmpty &&
          !query.toLowerCase().startsWith('my ') &&
          !query.toLowerCase().startsWith('contact')) {
        return ParsedCommand(kind: IntentKind.search, raw: text, target: query);
      }
    }

    final open = RegExp(r'^(?:open|launch|start|run)\s+(?:the\s+)?(.+?)(?:\s+app)?$')
        .firstMatch(text);
    if (open != null) {
      final target = open.group(1)?.trim() ?? '';
      if (target.isNotEmpty) {
        return ParsedCommand(kind: IntentKind.openApp, raw: text, target: target);
      }
    }

    if (lower.contains('time') && lower.length < 30) {
      return ParsedCommand(kind: IntentKind.help, raw: text, mode: 'time');
    }

    return ParsedCommand(kind: IntentKind.unknown, raw: text);
  }

  static String _settingsKind(String lower) {
    if (lower.contains('wi-fi') || lower.contains('wifi')) return 'wifi';
    if (lower.contains('bluetooth')) return 'bluetooth';
    if (lower.contains('display') || lower.contains('brightness')) return 'display';
    if (lower.contains('sound') || lower.contains('volume')) return 'sound';
    if (lower.contains('battery')) return 'battery';
    if (lower.contains('location') || lower.contains('gps')) return 'location';
    if (lower.contains('airplane') || lower.contains('flight')) return 'airplane';
    if (lower.contains('accessibility')) return 'accessibility';
    if (lower.contains('notification')) return 'notification_access';
    if (lower.contains('data')) return 'data';
    if (lower.contains('app')) return 'apps';
    if (lower.contains('developer')) return 'developer';
    return 'settings';
  }

  static List<String> suggestions(DeviceState device) {
    final list = <String>[
      if (!device.torchOn) 'Turn on the torch' else 'Turn off the torch',
      'Open WhatsApp',
      'Set brightness to 60%',
      if (!device.dndOn) 'Do not disturb on' else 'Do not disturb off',
      'Read my notifications',
      'Open Camera',
    ];
    return list.take(5).toList();
  }
}
