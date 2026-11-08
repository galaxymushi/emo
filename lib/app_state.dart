import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models.dart';
import 'services/cloud_brain.dart';
import 'services/command_engine.dart';
import 'services/device_bridge.dart';
import 'services/update_service.dart';
import 'services/voice_service.dart';

class _Outcome {
  const _Outcome({
    required this.reply,
    required this.title,
    required this.icon,
    this.status = ActivityStatus.success,
    this.needs,
  });

  final String reply;
  final String title;
  final String icon;
  final ActivityStatus status;
  final String? needs;
}

class AppState extends ChangeNotifier {
  AppState({DeviceBridge? bridge}) : bridge = bridge ?? DeviceBridge();

  final DeviceBridge bridge;
  final VoiceService voice = VoiceService();
  final CloudBrain cloud = CloudBrain();
  final UpdateService updateService = UpdateService();
  static const FlutterSecureStorage _secure = FlutterSecureStorage();

  SharedPreferences? _prefs;

  DeviceState device = DeviceState(available: false);
  bool booting = true;
  bool busy = false;
  int tab = 0;
  bool voiceReplies = true;
  bool keepHistory = true;
  double speechRate = 0.5;
  bool cloudEnabled = false;
  String cloudProviderId = CloudProvider.gemini.id;

  String appVersion = '';
  bool replyNotifications = true;
  bool updateNotifications = true;
  UpdateInfo? availableUpdate;
  bool checkingUpdate = false;
  String? updateError;
  bool inForeground = true;
  DateTime? _lastUpdateCheck;
  Timer? _updateTimer;

  bool get cloudReady => cloudEnabled && cloud.configured;
  String get cloudProviderName => CloudProvider.byId(cloudProviderId).name;

  List<ActivityEvent> activity = [];
  List<Routine> routines = [];
  List<ChatMessage> messages = [];
  final Set<String> runningRoutines = {};
  final Set<String> pendingQuick = {};

  bool get deviceReady => device.available;
  int get activeRoutines => routines.where((r) => r.enabled).length;

  Routine? get nextRoutine {
    Routine? best;
    int? bestMinutes;
    for (final r in routines) {
      final minutes = r.minutesUntilNext;
      if (minutes == null) continue;
      if (bestMinutes == null || minutes < bestMinutes) {
        best = r;
        bestMinutes = minutes;
      }
    }
    return best;
  }

  String get nextRoutineLabel {
    final next = nextRoutine;
    if (next == null) return 'No routines scheduled';
    final minutes = next.minutesUntilNext ?? 0;
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    final when =
        minutes < 60 ? 'in $mins min' : (hours < 24 ? 'in ${hours}h ${mins}m' : 'tomorrow');
    return '${next.name} · $when';
  }

  Future<void> boot() async {
    _prefs = await SharedPreferences.getInstance();
    voiceReplies = _prefs?.getBool('emo.voiceReplies') ?? true;
    keepHistory = _prefs?.getBool('emo.keepHistory') ?? true;
    speechRate = _prefs?.getDouble('emo.speechRate') ?? 0.5;
    replyNotifications = _prefs?.getBool('emo.notify.replies') ?? true;
    updateNotifications = _prefs?.getBool('emo.notify.updates') ?? true;
    appVersion = await bridge.appVersion();
    _loadRoutines();
    _loadActivity();
    await _loadCloud();
    messages = [
      ChatMessage(
        id: 'welcome',
        fromUser: false,
        text:
            "Hi — I'm Emo. Ask me to turn on the torch, open an app, call someone, or run a routine. I'll show every step as it happens.",
        time: DateTime.now(),
      ),
    ];
    await voice.init();
    voice.ttsEnabled = voiceReplies;
    await voice.setRate(speechRate);
    await voice.loadVoices();
    EmoVoice? chosen;
    final savedName = _prefs?.getString('emo.voice.name');
    final savedLocale = _prefs?.getString('emo.voice.locale');
    if (savedName != null) {
      for (final voiceOption in voice.voices) {
        if (voiceOption.name == savedName &&
            (savedLocale == null || voiceOption.locale == savedLocale)) {
          chosen = voiceOption;
          break;
        }
      }
    }
    chosen ??= voice.preferredVoice;
    if (chosen != null) await voice.applyVoice(chosen);
    await refreshDevice();
    await _syncRoutines();
    await consumeRoutineEvents();
    booting = false;
    notifyListeners();
    _updateTimer = Timer.periodic(
      const Duration(hours: 6),
      (_) => unawaited(checkForUpdates()),
    );
    if (updateNotifications) {
      unawaited(checkForUpdates());
    }
  }

  Future<void> _loadCloud() async {
    final providerId =
        _prefs?.getString('emo.cloud.provider') ?? CloudProvider.gemini.id;
    final provider = CloudProvider.byId(providerId);
    cloudProviderId = provider.id;
    cloudEnabled = _prefs?.getBool('emo.cloud.enabled') ?? false;
    final savedModel = _prefs?.getString('emo.cloud.model');
    cloud.model = CloudProvider.resolveModel(provider, savedModel);
    if (savedModel != null && savedModel != cloud.model) {
      await _prefs?.setString('emo.cloud.model', cloud.model);
    }
    final savedEndpoint = _prefs?.getString('emo.cloud.endpoint') ?? '';
    cloud.endpoint = provider.isCustom ? savedEndpoint : provider.endpoint;
    try {
      cloud.apiKey = await _secure.read(key: 'emo.cloud.key') ?? '';
    } catch (_) {
      cloud.apiKey = '';
    }
  }

  void _loadRoutines() {
    final raw = _prefs?.getString('emo.routines.v1');
    if (raw != null && raw.isNotEmpty) {
      try {
        routines = decodeRoutines(raw);
        return;
      } catch (_) {}
    }
    routines = _seedRoutines();
    _persistRoutines();
  }

  void _loadActivity() {
    final raw = _prefs?.getString('emo.activity.v1');
    if (raw != null && raw.isNotEmpty) {
      try {
        activity = decodeActivity(raw);
        return;
      } catch (_) {}
    }
    activity = _seedActivity();
    _persistActivity();
  }

  Future<void> refreshDevice() async {
    device = await bridge.getState();
    notifyListeners();
  }

  Future<void> handleResume() async {
    await refreshDevice();
    await consumeRoutineEvents();
  }

  Future<void> consumeRoutineEvents() async {
    final events = await bridge.consumeRoutineEvents();
    if (events.isEmpty) return;
    for (final event in events) {
      logEvent(
        title: '${event.routine} ran',
        detail: event.summary,
        status: event.ok ? ActivityStatus.success : ActivityStatus.failed,
        icon: 'moon',
        time: event.time,
      );
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Commands
  // ---------------------------------------------------------------------------

  Future<void> submitCommand(String raw, {bool speak = true}) async {
    final text = raw.trim();
    if (text.isEmpty || busy) return;
    final history = _cloudHistory();
    busy = true;
    messages.add(
      ChatMessage(
        id: 'u-${DateTime.now().microsecondsSinceEpoch}',
        fromUser: true,
        text: text,
        time: DateTime.now(),
      ),
    );
    final reply = ChatMessage(
      id: 'e-${DateTime.now().microsecondsSinceEpoch}',
      fromUser: false,
      text: '',
      time: DateTime.now(),
      working: true,
    );
    messages.add(reply);
    notifyListeners();
    await Future.delayed(const Duration(milliseconds: 320));

    var parsed = CommandParser.parse(text, device, routines);
    String? chatReply;
    String? cloudError;

    if (parsed.kind == IntentKind.unknown && cloudEnabled) {
      if (!cloud.configured) {
        cloudError = 'Cloud AI is on but has no API key. Add one in Settings.';
      } else {
        final step = _addStep(reply, 'Asking Emo Cloud');
        final result = await cloud.interpret(
          text: text,
          device: device,
          routines: routines,
          history: history,
        );
        if (result.command != null) {
          parsed = result.command!;
          step.status = ExecStatus.done;
          step.detail = 'Understood as ${result.actionName}';
        } else if (result.chat != null) {
          chatReply = result.chat;
          step.status = ExecStatus.done;
          step.detail = 'Answered';
        } else {
          cloudError = result.error ?? 'Cloud AI did not answer.';
          step.status = ExecStatus.failed;
          step.detail = cloudError;
        }
        notifyListeners();
      }
    }

    final outcome = chatReply != null
        ? _Outcome(
            reply: chatReply,
            title: 'Answered by Emo Cloud',
            icon: 'cloud',
            status: ActivityStatus.info,
          )
        : cloudError != null
            ? _Outcome(
                reply: '$cloudError Your offline commands still work.',
                title: 'Cloud AI unavailable',
                icon: 'cloud',
                status: ActivityStatus.failed,
              )
            : await _execute(parsed, reply);
    reply.text = outcome.reply;
    reply.working = false;
    reply.permissionNeed = outcome.needs;
    busy = false;
    notifyListeners();

    logEvent(
      title: outcome.title,
      detail: text,
      status: outcome.status,
      icon: outcome.icon,
    );
    if (!inForeground && replyNotifications && outcome.reply.trim().isNotEmpty) {
      await bridge.notifyReply(outcome.reply.trim());
    }
    if (speak) {
      await voice.speak(outcome.reply);
    }
  }

  List<Map<String, String>> _cloudHistory() {
    final recent = messages
        .where((message) => !message.working && message.text.trim().isNotEmpty)
        .toList();
    final start = recent.length > 8 ? recent.length - 8 : 0;
    return [
      for (final message in recent.sublist(start))
        {
          'role': message.fromUser ? 'user' : 'assistant',
          'content': message.text,
        },
    ];
  }

  Future<BridgeResult> quickAction(String kind) async {
    if (pendingQuick.contains(kind)) {
      return const BridgeResult(ok: false, message: 'Working on it.');
    }
    pendingQuick.add(kind);
    notifyListeners();
    final parsed = _quickIntent(kind);
    final holder = ChatMessage(
      id: 'quick',
      fromUser: false,
      text: '',
      time: DateTime.now(),
    );
    final outcome = await _execute(parsed, holder);
    pendingQuick.remove(kind);
    await refreshDevice();
    logEvent(
      title: outcome.title,
      detail: 'From quick controls',
      status: outcome.status,
      icon: outcome.icon,
    );
    notifyListeners();
    return BridgeResult(
      ok: outcome.status == ActivityStatus.success,
      message: outcome.reply,
      needs: outcome.needs,
    );
  }

  ParsedCommand _quickIntent(String kind) {
    switch (kind) {
      case 'torch':
        return ParsedCommand(
          kind: IntentKind.torch,
          raw: 'torch',
          on: !device.torchOn,
        );
      case 'wifi':
        return ParsedCommand(
          kind: IntentKind.wifi,
          raw: 'wifi',
          on: !device.wifiEnabled,
        );
      case 'bluetooth':
        return ParsedCommand(
          kind: IntentKind.bluetooth,
          raw: 'bluetooth',
          on: !device.bluetoothOn,
        );
      case 'dnd':
        return ParsedCommand(
          kind: IntentKind.dnd,
          raw: 'dnd',
          mode: device.dndOn ? 'off' : 'none',
        );
      default:
        return ParsedCommand(kind: IntentKind.unknown, raw: kind);
    }
  }

  ExecStep _addStep(ChatMessage holder, String label) {
    final step = ExecStep(label, status: ExecStatus.running);
    holder.steps.add(step);
    notifyListeners();
    return step;
  }

  Future<BridgeResult> _attempt(
    ChatMessage holder,
    String label,
    Future<BridgeResult> Function() action,
  ) async {
    final step = _addStep(holder, label);
    await Future.delayed(const Duration(milliseconds: 260));
    BridgeResult result;
    try {
      result = await action();
    } catch (e) {
      result = BridgeResult(ok: false, message: 'That did not work.');
    }
    step.status = result.ok ? ExecStatus.done : ExecStatus.failed;
    if (result.message.isNotEmpty) step.detail = result.message;
    notifyListeners();
    return result;
  }

  Future<_Outcome> _execute(ParsedCommand p, ChatMessage holder) async {
    switch (p.kind) {
      case IntentKind.torch:
        return _torch(p, holder);
      case IntentKind.wifi:
        return _wifi(p, holder);
      case IntentKind.bluetooth:
        return _bluetooth(p, holder);
      case IntentKind.dnd:
        return _dnd(p, holder);
      case IntentKind.brightness:
        return _brightness(p, holder);
      case IntentKind.volume:
        return _volume(p, holder);
      case IntentKind.openApp:
        return _openApp(p, holder);
      case IntentKind.call:
        return _call(p, holder);
      case IntentKind.message:
        return _message(p, holder);
      case IntentKind.settings:
        return _settings(p, holder);
      case IntentKind.battery:
        return _battery(holder);
      case IntentKind.notifications:
        return _notifications(p, holder);
      case IntentKind.clearNotifications:
        return _clearNotifications(holder);
      case IntentKind.back:
      case IntentKind.home:
      case IntentKind.recents:
      case IntentKind.notificationShade:
      case IntentKind.quickSettings:
      case IntentKind.lock:
      case IntentKind.screenshot:
        return _global(p, holder);
      case IntentKind.swipeUp:
      case IntentKind.swipeDown:
        return _swipe(p, holder);
      case IntentKind.search:
        return _search(p, holder);
      case IntentKind.runRoutine:
        return _routine(p, holder);
      case IntentKind.help:
        return _help(p);
      case IntentKind.unknown:
        return const _Outcome(
          reply:
              "I can't do that on this phone yet. Try “turn on the torch”, “open WhatsApp”, “call Alex” or “set brightness to 60%”.",
          title: 'Command not recognised',
          icon: 'help',
          status: ActivityStatus.failed,
        );
    }
  }

  Future<_Outcome> _torch(ParsedCommand p, ChatMessage holder) async {
    if (p.mode == 'status') {
      await refreshDevice();
      return _Outcome(
        reply: 'The torch is ${device.torchOn ? 'on' : 'off'}.',
        title: 'Torch status',
        icon: 'torch',
        status: ActivityStatus.info,
      );
    }
    final on = p.on ?? !device.torchOn;
    final label = on ? 'Turning the torch on' : 'Turning the torch off';
    var result = await _attempt(holder, label, () => bridge.setTorch(on));
    if (!result.ok && result.needs == 'camera') {
      final granted = await grantAccess('camera');
      if (granted) {
        result = await _attempt(holder, label, () => bridge.setTorch(on));
      }
    }
    await refreshDevice();
    if (result.ok) {
      return _Outcome(
        reply: on
            ? 'Torch is on. Tap the tile again to turn it off.'
            : 'Torch is off.',
        title: on ? 'Torch turned on' : 'Torch turned off',
        icon: 'torch',
      );
    }
    return _Outcome(
      reply: result.message.isNotEmpty
          ? result.message
          : "I couldn't control the torch.",
      title: 'Torch could not be changed',
      icon: 'torch',
      status: ActivityStatus.failed,
      needs: result.needs,
    );
  }

  Future<_Outcome> _wifi(ParsedCommand p, ChatMessage holder) async {
    if (p.mode == 'status') {
      await refreshDevice();
      final state = !device.wifiEnabled
          ? 'off'
          : (device.wifiConnected ? 'on and connected' : 'on but not connected');
      return _Outcome(
        reply: 'Wi-Fi is $state.',
        title: 'Wi-Fi status',
        icon: 'wifi',
        status: ActivityStatus.info,
      );
    }
    final on = p.on ?? !device.wifiEnabled;
    final result = await _attempt(
      holder,
      on ? 'Switching Wi-Fi on' : 'Switching Wi-Fi off',
      () => bridge.setWifi(on),
    );
    await refreshDevice();
    if (result.ok) {
      return _Outcome(
        reply: on ? 'Wi-Fi is on.' : 'Wi-Fi is off.',
        title: on ? 'Wi-Fi turned on' : 'Wi-Fi turned off',
        icon: 'wifi',
      );
    }
    if (result.needs == 'wifi_panel') {
      await _attempt(holder, 'Opening the system Wi-Fi panel', () => bridge.openPanel('wifi'));
      return const _Outcome(
        reply:
            'Android keeps Wi-Fi switching in the system panel, so I opened it for you. Change it there and the tile will update.',
        title: 'Wi-Fi panel opened',
        icon: 'wifi',
        status: ActivityStatus.info,
        needs: 'wifi_panel',
      );
    }
    return _Outcome(
      reply: result.message,
      title: 'Wi-Fi could not be changed',
      icon: 'wifi',
      status: ActivityStatus.failed,
      needs: result.needs,
    );
  }

  Future<_Outcome> _bluetooth(ParsedCommand p, ChatMessage holder) async {
    if (p.mode == 'status') {
      await refreshDevice();
      return _Outcome(
        reply: device.bluetoothSupported
            ? 'Bluetooth is ${device.bluetoothOn ? 'on' : 'off'}.'
            : 'This phone does not report Bluetooth support.',
        title: 'Bluetooth status',
        icon: 'bluetooth',
        status: ActivityStatus.info,
      );
    }
    final on = p.on ?? !device.bluetoothOn;
    final label = on ? 'Switching Bluetooth on' : 'Switching Bluetooth off';
    var result = await _attempt(holder, label, () => bridge.setBluetooth(on));
    if (!result.ok && result.needs == 'bluetooth') {
      final granted = await grantAccess('bluetooth');
      if (granted) {
        result = await _attempt(holder, label, () => bridge.setBluetooth(on));
      }
    }
    await refreshDevice();
    if (result.ok) {
      return _Outcome(
        reply: on ? 'Bluetooth is on.' : 'Bluetooth is off.',
        title: on ? 'Bluetooth turned on' : 'Bluetooth turned off',
        icon: 'bluetooth',
      );
    }
    if (result.needs == 'bluetooth_panel' || result.needs == 'bluetooth') {
      await _attempt(
        holder,
        'Opening the Bluetooth panel',
        () => bridge.openPanel('bluetooth'),
      );
      return const _Outcome(
        reply:
            'Android keeps Bluetooth switching in the system panel, so I opened it. Toggle Bluetooth there and I will pick up the change.',
        title: 'Bluetooth panel opened',
        icon: 'bluetooth',
        status: ActivityStatus.info,
        needs: 'bluetooth_panel',
      );
    }
    return _Outcome(
      reply: result.message,
      title: 'Bluetooth could not be changed',
      icon: 'bluetooth',
      status: ActivityStatus.failed,
      needs: result.needs,
    );
  }

  Future<_Outcome> _dnd(ParsedCommand p, ChatMessage holder) async {
    if (p.mode == 'status') {
      await refreshDevice();
      final state = !device.dndAccess
          ? 'Emo needs Do Not Disturb access to read it'
          : (device.dndOn
              ? (device.dndPriorityOnly
                  ? 'on, letting priority alerts through'
                  : 'on')
              : 'off');
      return _Outcome(
        reply: 'Do Not Disturb is $state.',
        title: 'Do Not Disturb status',
        icon: 'moon',
        status: ActivityStatus.info,
      );
    }
    final mode = p.mode ?? 'none';
    if (!device.dndAccess) {
      final step = _addStep(holder, 'Checking Do Not Disturb access');
      await Future.delayed(const Duration(milliseconds: 220));
      step.status = ExecStatus.failed;
      step.detail = 'Access not granted';
      notifyListeners();
      return const _Outcome(
        reply:
            'Emo needs Do Not Disturb access to change this. It takes one tap in Settings.',
        title: 'Do Not Disturb needs access',
        icon: 'moon',
        status: ActivityStatus.failed,
        needs: 'policy',
      );
    }
    final result = await _attempt(
      holder,
      mode == 'off'
          ? 'Turning Do Not Disturb off'
          : (mode == 'priority' ? 'Allowing priority alerts only' : 'Turning Do Not Disturb on'),
      () => bridge.setDnd(mode),
    );
    await refreshDevice();
    if (!result.ok) {
      return _Outcome(
        reply: result.message,
        title: 'Do Not Disturb could not be changed',
        icon: 'moon',
        status: ActivityStatus.failed,
        needs: result.needs,
      );
    }
    final reply = mode == 'off'
        ? 'Do Not Disturb is off.'
        : mode == 'priority'
            ? 'Do Not Disturb is on for everything except priority alerts.'
            : 'Do Not Disturb is on. Notifications will stay quiet.';
    return _Outcome(
      reply: reply,
      title: mode == 'off'
          ? 'Do Not Disturb turned off'
          : (mode == 'priority' ? 'Do Not Disturb set to priority' : 'Do Not Disturb turned on'),
      icon: 'moon',
    );
  }

  Future<_Outcome> _brightness(ParsedCommand p, ChatMessage holder) async {
    if (p.mode == 'status') {
      await refreshDevice();
      return _Outcome(
        reply: 'Screen brightness is at ${(device.brightness * 100).round()}%.',
        title: 'Brightness checked',
        icon: 'brightness',
        status: ActivityStatus.info,
      );
    }
    final value = clamp01(p.value ?? 0.5);
    final result = await _attempt(
      holder,
      'Setting screen brightness to ${(value * 100).round()}%',
      () => bridge.setBrightness(value),
    );
    await refreshDevice();
    if (!result.ok) {
      return _Outcome(
        reply: result.message,
        title: 'Brightness could not be changed',
        icon: 'brightness',
        status: ActivityStatus.failed,
        needs: result.needs,
      );
    }
    final limited = !device.canWriteSettings;
    return _Outcome(
      reply: limited
          ? 'Brightness is at ${(value * 100).round()}% while Emo is open. Allow system settings access to make it stick everywhere.'
          : 'Screen brightness is at ${(value * 100).round()}%.',
      title: 'Brightness set to ${(value * 100).round()}%',
      icon: 'brightness',
      status: limited ? ActivityStatus.info : ActivityStatus.success,
    );
  }

  Future<_Outcome> _volume(ParsedCommand p, ChatMessage holder) async {
    if (p.mode == 'status') {
      await refreshDevice();
      return _Outcome(
        reply:
            'Media volume is at ${(device.volumeMusic * 100).round()}%; the ringer is at ${(device.volumeRing * 100).round()}%.',
        title: 'Volume checked',
        icon: 'volume',
        status: ActivityStatus.info,
      );
    }
    final stream = p.mode ?? 'music';
    final value = clamp01(p.value ?? 0.5);
    final result = await _attempt(
      holder,
      'Setting ${stream == 'music' ? 'media' : stream} volume to ${(value * 100).round()}%',
      () => bridge.setVolume(stream, value),
    );
    await refreshDevice();
    if (!result.ok) {
      return _Outcome(
        reply: result.message,
        title: 'Volume could not be changed',
        icon: 'volume',
        status: ActivityStatus.failed,
        needs: result.needs,
      );
    }
    return _Outcome(
      reply: value == 0
          ? '${stream == 'music' ? 'Media' : stream.capitalize()} sound is muted.'
          : '${stream == 'music' ? 'Media' : stream.capitalize()} volume is at ${(value * 100).round()}%.',
      title: '${stream.capitalize()} volume set',
      icon: 'volume',
    );
  }

  Future<_Outcome> _openApp(ParsedCommand p, ChatMessage holder) async {
    final target = p.target ?? '';
    final result = await _attempt(holder, 'Looking for $target', () => bridge.openApp(target));
    if (result.ok) {
      return _Outcome(
        reply: '${result.message}. I will be here when you come back.',
        title: target.capitalize(),
        icon: 'apps',
      );
    }
    return _Outcome(
      reply: result.message.isNotEmpty
          ? '${result.message}. Try the full app name.'
          : "I couldn't find that app.",
      title: 'App not found',
      icon: 'apps',
      status: ActivityStatus.failed,
    );
  }

  Future<_Outcome> _call(ParsedCommand p, ChatMessage holder) async {
    final target = (p.target ?? '').trim();
    if (target.isEmpty) {
      return const _Outcome(
        reply: 'Who should I call?',
        title: 'Call failed',
        icon: 'phone',
        status: ActivityStatus.failed,
      );
    }
    if (RegExp(r'^[+\d][\d\s\-()]{2,}$').hasMatch(target)) {
      final result = await _attempt(holder, 'Opening the dialer', () => bridge.dial(target));
      return _Outcome(
        reply: result.ok
            ? 'The dialer is open with $target. Tap the call button to connect.'
            : result.message,
        title: 'Dialer opened',
        icon: 'phone',
        status: result.ok ? ActivityStatus.success : ActivityStatus.failed,
        needs: result.needs,
      );
    }

    var lookup = await _attempt(holder, 'Finding $target in contacts', () => bridge.findContact(target));
    if (!lookup.ok && lookup.needs == 'contacts') {
      final granted = await grantAccess('contacts');
      if (granted) {
        lookup = await _attempt(
          holder,
          'Finding $target in contacts',
          () => bridge.findContact(target),
        );
      }
    }
    if (!lookup.ok) {
      return _Outcome(
        reply: lookup.needs == 'contacts'
            ? 'Emo needs contact access to find $target.'
            : lookup.message.isNotEmpty
                ? lookup.message
                : 'I could not find $target.',
        title: 'Contact not found',
        icon: 'phone',
        status: ActivityStatus.failed,
        needs: lookup.needs,
      );
    }
    final contacts = (lookup.data?['contacts'] as List?) ?? const [];
    if (contacts.isEmpty) {
      return _Outcome(
        reply: 'I could not find a number for $target.',
        title: 'Contact not found',
        icon: 'phone',
        status: ActivityStatus.failed,
      );
    }
    final first = contacts.first as Map;
    final name = (first['name'] as String?) ?? target;
    final number = (first['number'] as String?) ?? '';
    final dial = await _attempt(holder, 'Opening the dialer for $name', () => bridge.dial(number));
    return _Outcome(
      reply: dial.ok
          ? 'The dialer is open for $name ($number). Tap the call button to connect.'
          : dial.message,
      title: 'Dialer opened for $name',
      icon: 'phone',
      status: dial.ok ? ActivityStatus.success : ActivityStatus.failed,
      needs: dial.needs,
    );
  }

  Future<_Outcome> _message(ParsedCommand p, ChatMessage holder) async {
    final target = (p.target ?? '').trim();
    if (target.isEmpty) {
      return const _Outcome(
        reply: 'Who should I message?',
        title: 'Message failed',
        icon: 'message',
        status: ActivityStatus.failed,
      );
    }
    var number = target;
    var name = target;
    if (!RegExp(r'^[+\d][\d\s\-()]{2,}$').hasMatch(target)) {
      var lookup = await _attempt(holder, 'Finding $target in contacts', () => bridge.findContact(target));
      if (!lookup.ok && lookup.needs == 'contacts') {
        final granted = await grantAccess('contacts');
        if (granted) {
          lookup = await _attempt(
            holder,
            'Finding $target in contacts',
            () => bridge.findContact(target),
          );
        }
      }
      if (!lookup.ok) {
        return _Outcome(
          reply: lookup.message.isNotEmpty
              ? lookup.message
              : 'I could not find a number for $target.',
          title: 'Contact not found',
          icon: 'message',
          status: ActivityStatus.failed,
          needs: lookup.needs,
        );
      }
      final contacts = (lookup.data?['contacts'] as List?) ?? const [];
      if (contacts.isEmpty) {
        return _Outcome(
          reply: 'I could not find a number for $target.',
          title: 'Contact not found',
          icon: 'message',
          status: ActivityStatus.failed,
        );
      }
      final first = contacts.first as Map;
      name = (first['name'] as String?) ?? target;
      number = (first['number'] as String?) ?? '';
    }
    final body = p.body ?? '';
    final result = await _attempt(
      holder,
      body.isEmpty ? 'Opening a message to $name' : 'Writing your message to $name',
      () => bridge.composeSms(number, body),
    );
    return _Outcome(
      reply: result.ok
          ? (body.isEmpty
              ? 'The message to $name is ready. Add your note and send it.'
              : 'Your message to $name is ready to send.')
          : result.message,
      title: result.ok ? 'Message drafted for $name' : 'Message could not be opened',
      icon: 'message',
      status: result.ok ? ActivityStatus.success : ActivityStatus.failed,
      needs: result.needs,
    );
  }

  Future<_Outcome> _settings(ParsedCommand p, ChatMessage holder) async {
    final kind = p.mode ?? 'settings';
    final labels = {
      'wifi': 'Wi-Fi settings',
      'bluetooth': 'Bluetooth settings',
      'display': 'Display settings',
      'sound': 'Sound settings',
      'battery': 'Battery settings',
      'location': 'Location settings',
      'airplane': 'Airplane mode settings',
      'accessibility': 'Accessibility settings',
      'notification_access': 'Notification access',
      'data': 'Network settings',
      'apps': 'App settings',
      'developer': 'Developer options',
      'settings': 'Settings',
    };
    final result = await _attempt(
      holder,
      'Opening ${labels[kind] ?? 'Settings'}',
      () => bridge.openPanel(kind),
    );
    return _Outcome(
      reply: result.ok ? '${labels[kind] ?? 'Settings'} is open.' : result.message,
      title: 'Opened ${labels[kind] ?? 'Settings'}',
      icon: 'settings',
      status: result.ok ? ActivityStatus.success : ActivityStatus.failed,
    );
  }

  Future<_Outcome> _battery(ChatMessage holder) async {
    final step = _addStep(holder, 'Reading the battery');
    await Future.delayed(const Duration(milliseconds: 260));
    await refreshDevice();
    step.status = ExecStatus.done;
    step.detail = '${device.battery}%';
    notifyListeners();
    final suffix = device.charging ? ' and charging' : '';
    return _Outcome(
      reply: device.battery >= 0
          ? 'Battery is at ${device.battery}%$suffix.'
          : 'I could not read the battery level.',
      title: 'Battery checked',
      icon: 'battery',
      status: device.battery >= 0 ? ActivityStatus.success : ActivityStatus.failed,
    );
  }

  Future<_Outcome> _notifications(ParsedCommand p, ChatMessage holder) async {
    if (p.mode == 'shade') {
      final result = await _attempt(
        holder,
        'Opening the notification shade',
        () => bridge.globalAction('notifications'),
      );
      if (result.ok) {
        return const _Outcome(
          reply: 'The notification shade is open.',
          title: 'Notification shade opened',
          icon: 'bell',
        );
      }
      return _Outcome(
        reply: result.message,
        title: 'Could not open notifications',
        icon: 'bell',
        status: ActivityStatus.failed,
        needs: result.needs,
      );
    }
    if (!device.notificationAccess) {
      final step = _addStep(holder, 'Checking notification access');
      await Future.delayed(const Duration(milliseconds: 240));
      step.status = ExecStatus.failed;
      step.detail = 'Access not granted';
      notifyListeners();
      return const _Outcome(
        reply:
            'Emo needs notification access to read what is waiting. You can grant it in Settings.',
        title: 'Notification access needed',
        icon: 'bell',
        status: ActivityStatus.failed,
        needs: 'notification_access',
      );
    }
    final step = _addStep(holder, 'Reading your notifications');
    await Future.delayed(const Duration(milliseconds: 420));
    final items = await bridge.getNotifications();
    step.status = ExecStatus.done;
    step.detail = '${items.length} found';
    notifyListeners();
    await refreshDevice();
    if (items.isEmpty) {
      return const _Outcome(
        reply: 'Nothing is waiting — your notification shade is clear.',
        title: 'Notifications checked',
        icon: 'bell',
        status: ActivityStatus.info,
      );
    }
    final preview = items.take(3).map((n) {
      final title = n.title.isNotEmpty ? n.title : n.app;
      return n.text.isEmpty ? '$title (${n.app})' : '$title: ${n.text}';
    }).join('. ');
    return _Outcome(
      reply:
          'You have ${items.length} notification${items.length == 1 ? '' : 's'}. $preview.',
      title: 'Read ${items.length} notifications',
      icon: 'bell',
    );
  }

  Future<_Outcome> _clearNotifications(ChatMessage holder) async {
    final result = await _attempt(
      holder,
      'Clearing notifications',
      () => bridge.dismissNotifications(),
    );
    return _Outcome(
      reply: result.ok ? 'Notifications cleared.' : result.message,
      title: result.ok ? 'Notifications cleared' : 'Could not clear notifications',
      icon: 'bell',
      status: result.ok ? ActivityStatus.success : ActivityStatus.failed,
      needs: result.needs,
    );
  }

  Future<_Outcome> _global(ParsedCommand p, ChatMessage holder) async {
    final (String action, String label, String reply, String title, String icon) =
        switch (p.kind) {
      IntentKind.back => ('back', 'Going back', 'Went back.', 'Went back', 'back'),
      IntentKind.home => ('home', 'Going to the home screen', 'Home screen.', 'Went home', 'home'),
      IntentKind.recents => ('recents', 'Opening recent apps', 'Recent apps are open.', 'Opened recents', 'recents'),
      IntentKind.notificationShade => ('notifications', 'Opening notifications', 'Notifications are open.', 'Opened notifications', 'bell'),
      IntentKind.quickSettings => ('quick_settings', 'Opening quick settings', 'Quick settings are open.', 'Opened quick settings', 'quick'),
      IntentKind.lock => ('lock', 'Locking the phone', 'The phone is locked.', 'Locked the phone', 'lock'),
      IntentKind.screenshot => ('screenshot', 'Taking a screenshot', 'Screenshot taken.', 'Took a screenshot', 'screenshot'),
      _ => ('home', 'Going home', 'Home.', 'Went home', 'home'),
    };
    final result = await _attempt(holder, label, () => bridge.globalAction(action));
    return _Outcome(
      reply: result.ok ? reply : result.message,
      title: result.ok ? title : 'Action needs accessibility',
      icon: result.ok ? icon : 'lock',
      status: result.ok ? ActivityStatus.success : ActivityStatus.failed,
      needs: result.needs,
    );
  }

  Future<_Outcome> _swipe(ParsedCommand p, ChatMessage holder) async {
    final direction = p.mode ?? 'up';
    final result = await _attempt(
      holder,
      'Scrolling ${direction == 'up' ? 'down' : 'up'}',
      () => bridge.swipe(direction),
    );
    return _Outcome(
      reply: result.ok
          ? (direction == 'up' ? 'Scrolled down.' : 'Scrolled up.')
          : result.message,
      title: 'Scroll gesture',
      icon: 'swipe',
      status: result.ok ? ActivityStatus.success : ActivityStatus.failed,
      needs: result.needs,
    );
  }

  Future<_Outcome> _search(ParsedCommand p, ChatMessage holder) async {
    final query = p.target ?? '';
    final url = 'https://www.google.com/search?q=${Uri.encodeComponent(query)}';
    final result = await _attempt(holder, 'Searching for “$query”', () => bridge.openUrl(url));
    return _Outcome(
      reply: result.ok ? 'Searching the web for “$query”.' : result.message,
      title: 'Searched for “$query”',
      icon: 'search',
      status: result.ok ? ActivityStatus.success : ActivityStatus.failed,
    );
  }

  Future<_Outcome> _routine(ParsedCommand p, ChatMessage holder) async {
    final routine = p.routine;
    if (routine == null) {
      return const _Outcome(
        reply: 'Which routine should I run?',
        title: 'Routine not found',
        icon: 'sparkle',
        status: ActivityStatus.failed,
      );
    }
    final step = _addStep(holder, 'Running ${routine.name}');
    await Future.delayed(const Duration(milliseconds: 280));
    final summary = await runRoutine(routine, log: false);
    step.status = ExecStatus.done;
    step.detail = summary;
    notifyListeners();
    return _Outcome(
      reply: summary.isEmpty
          ? '${routine.name} has no actions yet.'
          : '${routine.name} ran: $summary.',
      title: '${routine.name} ran',
      icon: routine.iconKey,
      status: summary.isEmpty ? ActivityStatus.info : ActivityStatus.success,
    );
  }

  Future<_Outcome> _help(ParsedCommand p) async {
    if (p.mode == 'greeting') {
      return _Outcome(
        reply: 'Hi. What would you like your phone to do?',
        title: 'Greeting',
        icon: 'sparkle',
        status: ActivityStatus.info,
      );
    }
    if (p.mode == 'time') {
      final now = DateTime.now();
      return _Outcome(
        reply: 'It is ${formatTime(now)}.',
        title: 'Time checked',
        icon: 'help',
        status: ActivityStatus.info,
      );
    }
    return const _Outcome(
      reply:
          'I can switch the torch, open apps, set brightness and volume, control Do Not Disturb, read and clear notifications, navigate your phone, call or message contacts, and run your routines. Voice replies are on by default.',
      title: 'Showed capabilities',
      icon: 'help',
      status: ActivityStatus.info,
    );
  }

  // ---------------------------------------------------------------------------
  // Routines
  // ---------------------------------------------------------------------------

  Future<String> runRoutine(Routine routine, {bool log = true}) async {
    if (runningRoutines.contains(routine.id)) return 'Already running';
    runningRoutines.add(routine.id);
    notifyListeners();
    final results = <String>[];
    var failed = false;

    for (final action in routine.actions) {
      switch (action.type) {
        case 'torch':
          final on = action.value == true;
          final r = await bridge.setTorch(on);
          if (r.ok) {
            results.add(on ? 'Torch on' : 'Torch off');
          } else {
            failed = true;
            results.add('Torch failed');
          }
        case 'dnd':
          if (!device.dndAccess) {
            failed = true;
            results.add('DND needs access');
          } else {
            final mode = (action.value as String?) ?? 'none';
            final r = await bridge.setDnd(mode);
            if (r.ok) {
              results.add(mode == 'off' ? 'DND off' : 'DND on');
            } else {
              failed = true;
              results.add('DND failed');
            }
          }
        case 'volume':
          final value = (action.value as num?)?.toDouble() ?? 0.5;
          final r = await bridge.setVolume(action.stream ?? 'music', value);
          if (r.ok) {
            results.add('Volume ${(value * 100).round()}%');
          } else {
            failed = true;
            results.add('Volume failed');
          }
        case 'brightness':
          final value = (action.value as num?)?.toDouble() ?? 0.5;
          final r = await bridge.setBrightness(value);
          if (r.ok) {
            results.add('Brightness ${(value * 100).round()}%');
          } else {
            failed = true;
            results.add('Brightness failed');
          }
        default:
          results.add('Unsupported action');
      }
    }

    runningRoutines.remove(routine.id);
    await refreshDevice();
    if (log) {
      logEvent(
        title: '${routine.name} ran',
        detail: results.join(' · '),
        status: failed ? ActivityStatus.failed : ActivityStatus.success,
        icon: routine.iconKey,
      );
    }
    notifyListeners();
    return results.join(' · ');
  }

  Future<void> toggleRoutine(Routine routine, bool enabled) async {
    final index = routines.indexWhere((r) => r.id == routine.id);
    if (index == -1) return;
    routines[index] = routine.copyWith(enabled: enabled);
    _persistRoutines();
    await _syncRoutines();
    logEvent(
      title: enabled ? '${routine.name} enabled' : '${routine.name} paused',
      detail: routine.triggerLabel,
      status: ActivityStatus.info,
      icon: routine.iconKey,
    );
    notifyListeners();
  }

  Future<void> saveRoutine(Routine routine, {bool isNew = false}) async {
    final index = routines.indexWhere((r) => r.id == routine.id);
    if (index == -1) {
      routines.add(routine);
    } else {
      routines[index] = routine;
    }
    _persistRoutines();
    await _syncRoutines();
    logEvent(
      title: isNew ? 'Routine created' : 'Routine updated',
      detail: '${routine.name} · ${routine.triggerLabel}',
      status: ActivityStatus.info,
      icon: routine.iconKey,
    );
    notifyListeners();
  }

  Future<void> deleteRoutine(String id) async {
    Routine? routine;
    for (final r in routines) {
      if (r.id == id) {
        routine = r;
        break;
      }
    }
    routines.removeWhere((r) => r.id == id);
    _persistRoutines();
    await _syncRoutines();
    if (routine != null) {
      logEvent(
        title: 'Routine deleted',
        detail: routine.name,
        status: ActivityStatus.info,
        icon: routine.iconKey,
      );
    }
    notifyListeners();
  }

  Future<void> _syncRoutines() async {
    await bridge.syncRoutines(routines);
  }

  // ---------------------------------------------------------------------------
  // Settings
  // ---------------------------------------------------------------------------

  Future<bool> grantAccess(String need) async {
    switch (need) {
      case 'camera':
      case 'contacts':
      case 'microphone':
      case 'notifications':
      case 'bluetooth':
        final result = await bridge.requestPermission(need);
        await refreshDevice();
        return result.ok;
      case 'policy':
        await bridge.openPanel('policy_access');
        return false;
      case 'accessibility':
        await bridge.openPanel('accessibility');
        return false;
      case 'notification_access':
        await bridge.openPanel('notification_access');
        return false;
      case 'write_settings':
        await bridge.openPanel('write_settings');
        return false;
      case 'wifi_panel':
        await bridge.openPanel('wifi');
        return false;
      case 'bluetooth_panel':
        await bridge.openPanel('bluetooth');
        return false;
      default:
        return false;
    }
  }

  Future<void> setVoiceReplies(bool value) async {
    voiceReplies = value;
    await voice.setEnabled(value);
    await _prefs?.setBool('emo.voiceReplies', value);
    notifyListeners();
  }

  Future<void> setSpeechRate(double value) async {
    speechRate = value;
    await voice.setRate(value);
    await _prefs?.setDouble('emo.speechRate', value);
    notifyListeners();
  }

  String get voiceLabel => voice.currentVoice?.label ?? 'Phone default';

  Future<void> ensureVoices() async {
    if (voice.voices.isEmpty) {
      await voice.loadVoices();
      notifyListeners();
    }
  }

  Future<void> setEmoVoice(EmoVoice value) async {
    await voice.applyVoice(value);
    await _prefs?.setString('emo.voice.name', value.name);
    await _prefs?.setString('emo.voice.locale', value.locale);
    notifyListeners();
  }

  Future<void> resetEmoVoice() async {
    await _prefs?.remove('emo.voice.name');
    await _prefs?.remove('emo.voice.locale');
    final fallback = voice.preferredVoice;
    if (fallback != null) await voice.applyVoice(fallback);
    notifyListeners();
  }

  Future<void> setCloudEnabled(bool value) async {
    cloudEnabled = value;
    await _prefs?.setBool('emo.cloud.enabled', value);
    notifyListeners();
  }

  Future<void> setReplyNotifications(bool value) async {
    if (value && !device.notificationPermission) {
      final granted = await grantAccess('notifications');
      if (!granted) return;
    }
    replyNotifications = value;
    await _prefs?.setBool('emo.notify.replies', value);
    notifyListeners();
  }

  Future<void> setUpdateNotifications(bool value) async {
    if (value && !device.notificationPermission) {
      final granted = await grantAccess('notifications');
      if (!granted) return;
    }
    updateNotifications = value;
    await _prefs?.setBool('emo.notify.updates', value);
    notifyListeners();
    if (value) unawaited(checkForUpdates());
  }

  Future<void> checkForUpdates({bool manual = false}) async {
    if (checkingUpdate) return;
    if (appVersion.isEmpty) appVersion = await bridge.appVersion();
    if (appVersion.isEmpty) return;
    checkingUpdate = true;
    if (manual) updateError = null;
    notifyListeners();
    try {
      final info = await updateService.check(appVersion);
      availableUpdate = info;
      _lastUpdateCheck = DateTime.now();
      if (info != null &&
          updateNotifications &&
          _prefs?.getString('emo.update.seen') != info.version) {
        final posted = await bridge.notifyUpdate(
          version: info.version,
          url: info.apkUrl,
          notes: info.notes,
        );
        if (posted) await _prefs?.setString('emo.update.seen', info.version);
      }
    } catch (_) {
      if (manual) updateError = 'Could not check for updates. Try again later.';
    } finally {
      checkingUpdate = false;
      notifyListeners();
    }
  }

  Future<void> openUpdate() async {
    final url = availableUpdate?.apkUrl ??
        'https://github.com/${UpdateService.repository}/releases/latest';
    await bridge.openUrl(url);
  }

  void setForeground(bool value) {
    inForeground = value;
    if (!value) return;
    final last = _lastUpdateCheck;
    if (last == null || DateTime.now().difference(last) > const Duration(hours: 6)) {
      unawaited(checkForUpdates());
    }
  }

  Future<void> saveCloudConfig({
    required String providerId,
    required String apiKey,
    required String model,
    required String endpoint,
  }) async {
    final provider = CloudProvider.byId(providerId);
    cloudProviderId = provider.id;
    cloud.apiKey = apiKey.trim();
    cloud.model = CloudProvider.resolveModel(provider, model);
    cloud.endpoint = provider.isCustom ? endpoint.trim() : provider.endpoint;
    await _prefs?.setString('emo.cloud.provider', provider.id);
    await _prefs?.setString('emo.cloud.model', cloud.model);
    await _prefs?.setString('emo.cloud.endpoint', cloud.endpoint);
    try {
      if (cloud.apiKey.isEmpty) {
        await _secure.delete(key: 'emo.cloud.key');
      } else {
        await _secure.write(key: 'emo.cloud.key', value: cloud.apiKey);
      }
    } catch (_) {}
    if (cloud.apiKey.isEmpty) {
      cloudEnabled = false;
      await _prefs?.setBool('emo.cloud.enabled', false);
    }
    notifyListeners();
  }

  Future<String?> testCloudConfig({
    required String providerId,
    required String apiKey,
    required String model,
    required String endpoint,
  }) async {
    final provider = CloudProvider.byId(providerId);
    final probe = CloudBrain();
    probe.apiKey = apiKey.trim();
    probe.model = model.trim().isEmpty ? provider.model : model.trim();
    probe.endpoint = provider.isCustom ? endpoint.trim() : provider.endpoint;
    try {
      return await probe.testConnection();
    } finally {
      probe.close();
    }
  }

  Future<void> setKeepHistory(bool value) async {
    keepHistory = value;
    await _prefs?.setBool('emo.keepHistory', value);
    if (!value) await _prefs?.remove('emo.activity.v1');
    notifyListeners();
  }

  Future<void> clearHistory() async {
    activity = [];
    _persistActivity();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Activity
  // ---------------------------------------------------------------------------

  void logEvent({
    required String title,
    required String detail,
    required ActivityStatus status,
    required String icon,
    DateTime? time,
  }) {
    final event = ActivityEvent(
      id: 'a-${DateTime.now().microsecondsSinceEpoch}-${activity.length}',
      title: title,
      detail: detail,
      time: time ?? DateTime.now(),
      status: status,
      icon: icon,
    );
    activity.insert(0, event);
    if (activity.length > 90) activity = activity.sublist(0, 90);
    _persistActivity();
    notifyListeners();
  }

  void setTab(int index) {
    tab = index;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  void _persistRoutines() {
    _prefs?.setString(
      'emo.routines.v1',
      encodeRoutines(routines),
    );
  }

  void _persistActivity() {
    if (!keepHistory) return;
    _prefs?.setString(
      'emo.activity.v1',
      encodeActivity(activity),
    );
  }

  // ---------------------------------------------------------------------------
  // Seed data
  // ---------------------------------------------------------------------------

  List<Routine> _seedRoutines() => [
        const Routine(
          id: 'focus-time',
          name: 'Focus time',
          iconKey: 'focus',
          enabled: true,
          trigger: 'time',
          time: '09:00',
          actions: [
            RoutineAction(
              type: 'dnd',
              label: 'Do Not Disturb · Priority',
              value: 'priority',
            ),
          ],
        ),
        const Routine(
          id: 'wind-down',
          name: 'Wind down',
          iconKey: 'moon',
          enabled: true,
          trigger: 'time',
          time: '22:30',
          actions: [
            RoutineAction(type: 'dnd', label: 'Do Not Disturb on', value: 'none'),
            RoutineAction(
              type: 'volume',
              label: 'Volume 30%',
              value: 0.3,
              stream: 'music',
            ),
            RoutineAction(type: 'torch', label: 'Torch off', value: false),
          ],
        ),
        const Routine(
          id: 'movie-mode',
          name: 'Movie mode',
          iconKey: 'movie',
          enabled: true,
          trigger: 'manual',
          time: '20:00',
          actions: [
            RoutineAction(
              type: 'brightness',
              label: 'Brightness 25%',
              value: 0.25,
            ),
            RoutineAction(
              type: 'volume',
              label: 'Volume 45%',
              value: 0.45,
              stream: 'music',
            ),
          ],
        ),
      ];

  List<ActivityEvent> _seedActivity() {
    return [
      ActivityEvent(
        id: 'welcome-${DateTime.now().millisecondsSinceEpoch}',
        title: 'Emo is ready',
        detail: 'Grant access in Settings to unlock every action',
        time: DateTime.now(),
        status: ActivityStatus.info,
        icon: 'sparkle',
      ),
    ];
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    updateService.close();
    cloud.close();
    super.dispose();
  }
}

String encodeRoutines(List<Routine> routines) {
  final buffer = StringBuffer('[');
  for (var i = 0; i < routines.length; i++) {
    if (i > 0) buffer.write(',');
    buffer.write(jsonEncode(routines[i].toJson()));
  }
  buffer.write(']');
  return buffer.toString();
}

List<Routine> decodeRoutines(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) return [];
  return decoded
      .whereType<Map>()
      .map((e) => Routine.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

String encodeActivity(List<ActivityEvent> events) {
  final buffer = StringBuffer('[');
  for (var i = 0; i < events.length; i++) {
    if (i > 0) buffer.write(',');
    buffer.write(jsonEncode(events[i].toJson()));
  }
  buffer.write(']');
  return buffer.toString();
}

List<ActivityEvent> decodeActivity(String raw) {
  final decoded = jsonDecode(raw);
  if (decoded is! List) return [];
  return decoded
      .whereType<Map>()
      .map((e) => ActivityEvent.fromJson(Map<String, dynamic>.from(e)))
      .toList();
}

extension StringX on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
