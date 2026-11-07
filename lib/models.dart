import 'dart:math' as math;

class DeviceState {
  const DeviceState({
    this.available = false,
    this.error,
    this.model = '',
    this.manufacturer = '',
    this.androidSdk = 0,
    this.wifiConnected = false,
    this.wifiEnabled = false,
    this.bluetoothSupported = false,
    this.bluetoothOn = false,
    this.dndFilter = 1,
    this.dndAccess = false,
    this.torchOn = false,
    this.hasFlash = false,
    this.battery = 0,
    this.charging = false,
    this.brightness = 0.5,
    this.volumeMusic = 0.5,
    this.volumeRing = 0.5,
    this.volumeAlarm = 0.5,
    this.canWriteSettings = false,
    this.accessibility = false,
    this.notificationAccess = false,
    this.notificationCount = 0,
    this.shizukuInstalled = false,
    this.cameraPermission = false,
    this.contactsPermission = false,
    this.microphonePermission = false,
    this.notificationPermission = false,
    this.bluetoothPermission = false,
  });

  final bool available;
  final String? error;
  final String model;
  final String manufacturer;
  final int androidSdk;
  final bool wifiConnected;
  final bool wifiEnabled;
  final bool bluetoothSupported;
  final bool bluetoothOn;
  final int dndFilter;
  final bool dndAccess;
  final bool torchOn;
  final bool hasFlash;
  final int battery;
  final bool charging;
  final double brightness;
  final double volumeMusic;
  final double volumeRing;
  final double volumeAlarm;
  final bool canWriteSettings;
  final bool accessibility;
  final bool notificationAccess;
  final int notificationCount;
  final bool shizukuInstalled;
  final bool cameraPermission;
  final bool contactsPermission;
  final bool microphonePermission;
  final bool notificationPermission;
  final bool bluetoothPermission;

  bool get dndOn => dndFilter != 1 && dndFilter != 0;
  bool get dndPriorityOnly => dndFilter == 2;
  String get dndLabel => dndFilter == 2 ? 'Priority' : (dndOn ? 'On' : 'Off');
  String get deviceName => model.isEmpty ? 'This phone' : model;

  factory DeviceState.unsupported(String message) =>
      DeviceState(available: false, error: message);

  factory DeviceState.fromMap(Map<dynamic, dynamic> map) {
    bool b(String key) => map[key] == true;
    int i(String key) => (map[key] as num?)?.toInt() ?? 0;
    double d(String key) => (map[key] as num?)?.toDouble() ?? 0;
    String s(String key) => (map[key] as String?) ?? '';
    return DeviceState(
      available: true,
      model: s('model'),
      manufacturer: s('manufacturer'),
      androidSdk: i('androidSdk'),
      wifiConnected: b('wifiConnected'),
      wifiEnabled: b('wifiEnabled'),
      bluetoothSupported: b('bluetoothSupported'),
      bluetoothOn: b('bluetoothOn'),
      dndFilter: i('dndFilter'),
      dndAccess: b('dndAccess'),
      torchOn: b('torchOn'),
      hasFlash: b('hasFlash'),
      battery: i('battery'),
      charging: b('charging'),
      brightness: d('brightness'),
      volumeMusic: d('volumeMusic'),
      volumeRing: d('volumeRing'),
      volumeAlarm: d('volumeAlarm'),
      canWriteSettings: b('canWriteSettings'),
      accessibility: b('accessibility'),
      notificationAccess: b('notificationAccess'),
      notificationCount: i('notificationCount'),
      shizukuInstalled: b('shizukuInstalled'),
      cameraPermission: b('cameraPermission'),
      contactsPermission: b('contactsPermission'),
      microphonePermission: b('microphonePermission'),
      notificationPermission: b('notificationPermission'),
      bluetoothPermission: b('bluetoothPermission'),
    );
  }
}

enum ActivityStatus { success, failed, running, info }

class ActivityEvent {
  ActivityEvent({
    required this.id,
    required this.title,
    required this.detail,
    required this.time,
    required this.status,
    this.icon = 'bolt',
  });

  final String id;
  final String title;
  final String detail;
  final DateTime time;
  final ActivityStatus status;
  final String icon;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'detail': detail,
        'time': time.millisecondsSinceEpoch,
        'status': status.name,
        'icon': icon,
      };

  factory ActivityEvent.fromJson(Map<String, dynamic> json) => ActivityEvent(
        id: json['id'] as String? ?? 'event',
        title: json['title'] as String? ?? '',
        detail: json['detail'] as String? ?? '',
        time: DateTime.fromMillisecondsSinceEpoch(
          (json['time'] as num?)?.toInt() ?? 0,
        ),
        status: ActivityStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => ActivityStatus.info,
        ),
        icon: json['icon'] as String? ?? 'bolt',
      );

  String get relativeTime {
    final diff = DateTime.now().difference(time);
    if (diff.inSeconds < 45) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${time.day}/${time.month}/${time.year}';
  }
}

class RoutineAction {
  const RoutineAction({
    required this.type,
    required this.label,
    this.value,
    this.stream,
  });

  final String type;
  final String label;
  final dynamic value;
  final String? stream;

  Map<String, dynamic> toJson() => {
        'type': type,
        'label': label,
        'value': value,
        if (stream != null) 'stream': stream,
      };

  Map<String, dynamic> toNativeJson() => {
        'type': type,
        'value': value,
        if (stream != null) 'stream': stream,
      };

  factory RoutineAction.fromJson(Map<String, dynamic> json) => RoutineAction(
        type: json['type'] as String? ?? 'torch',
        label: json['label'] as String? ?? '',
        value: json['value'],
        stream: json['stream'] as String?,
      );
}

class Routine {
  const Routine({
    required this.id,
    required this.name,
    required this.iconKey,
    required this.enabled,
    required this.trigger,
    required this.time,
    required this.actions,
  });

  final String id;
  final String name;
  final String iconKey;
  final bool enabled;
  final String trigger; // time | manual
  final String time; // HH:mm
  final List<RoutineAction> actions;

  bool get isManual => trigger == 'manual';
  String get triggerLabel => isManual ? 'Manual · tap to run' : 'Every day · $time';
  String get actionSummary => actions.map((a) => a.label).join(' · ');

  Routine copyWith({
    String? name,
    String? iconKey,
    bool? enabled,
    String? trigger,
    String? time,
    List<RoutineAction>? actions,
  }) =>
      Routine(
        id: id,
        name: name ?? this.name,
        iconKey: iconKey ?? this.iconKey,
        enabled: enabled ?? this.enabled,
        trigger: trigger ?? this.trigger,
        time: time ?? this.time,
        actions: actions ?? this.actions,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'iconKey': iconKey,
        'enabled': enabled,
        'trigger': trigger,
        'time': time,
        'actions': actions.map((a) => a.toJson()).toList(),
      };

  Map<String, dynamic> toNativeJson() => {
        'id': id,
        'name': name,
        'enabled': enabled,
        'trigger': trigger,
        'time': time,
        'actions': actions.map((a) => a.toNativeJson()).toList(),
      };

  factory Routine.fromJson(Map<String, dynamic> json) => Routine(
        id: json['id'] as String? ?? 'routine',
        name: json['name'] as String? ?? 'Routine',
        iconKey: json['iconKey'] as String? ?? 'sparkle',
        enabled: json['enabled'] as bool? ?? true,
        trigger: json['trigger'] as String? ?? 'time',
        time: json['time'] as String? ?? '08:00',
        actions: ((json['actions'] as List?) ?? [])
            .whereType<Map>()
            .map((e) => RoutineAction.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  /// Minutes since midnight of the next run, or null when disabled/manual.
  int? get minutesUntilNext {
    if (!enabled || isManual) return null;
    final parts = time.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final now = DateTime.now();
    final target = DateTime(now.year, now.month, now.day, hour, minute);
    final next = target.isBefore(now) ? target.add(const Duration(days: 1)) : target;
    return next.difference(now).inMinutes;
  }
}

enum ExecStatus { pending, running, done, failed }

class ExecStep {
  ExecStep(this.label, {this.status = ExecStatus.pending, this.detail});

  final String label;
  ExecStatus status;
  String? detail;
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.fromUser,
    required this.text,
    required this.time,
    List<ExecStep>? steps,
    this.working = false,
    this.permissionNeed,
    this.tone = 'normal',
  }) : steps = steps ?? [];

  final String id;
  final bool fromUser;
  String text;
  final DateTime time;
  final List<ExecStep> steps;
  bool working;
  String? permissionNeed;
  final String tone;

  bool get hasSteps => steps.isNotEmpty;
}

class BridgeResult {
  const BridgeResult({
    required this.ok,
    this.message = '',
    this.needs,
    this.data,
  });

  final bool ok;
  final String message;
  final String? needs;
  final dynamic data;

  factory BridgeResult.fromMap(dynamic raw) {
    if (raw is Map) {
      return BridgeResult(
        ok: raw['ok'] == true,
        message: (raw['message'] as String?) ?? '',
        needs: raw['needs'] as String?,
        data: raw,
      );
    }
    return BridgeResult(ok: raw == true);
  }
}

class AppNotification {
  const AppNotification({
    required this.app,
    required this.title,
    required this.text,
    required this.time,
    this.tint,
  });

  final String app;
  final String title;
  final String text;
  final DateTime time;
  final int? tint;

  factory AppNotification.fromMap(Map<dynamic, dynamic> map) => AppNotification(
        app: (map['app'] as String?) ?? 'App',
        title: (map['title'] as String?) ?? '',
        text: (map['text'] as String?) ?? '',
        time: DateTime.fromMillisecondsSinceEpoch(
          (map['time'] as num?)?.toInt() ?? 0,
        ),
      );
}

class RoutineEvent {
  const RoutineEvent({
    required this.routine,
    required this.time,
    required this.ok,
    required this.summary,
  });

  final String routine;
  final DateTime time;
  final bool ok;
  final String summary;

  factory RoutineEvent.fromMap(Map<dynamic, dynamic> map) => RoutineEvent(
        routine: (map['routine'] as String?) ?? 'Routine',
        time: DateTime.fromMillisecondsSinceEpoch(
          (map['time'] as num?)?.toInt() ?? 0,
        ),
        ok: map['ok'] == true,
        summary: (map['summary'] as String?) ?? '',
      );
}

String formatTime(DateTime time) {
  final hour = time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
  final minute = time.minute.toString().padLeft(2, '0');
  final suffix = time.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $suffix';
}

String greetingFor(DateTime time) {
  if (time.hour < 12) return 'Good morning';
  if (time.hour < 17) return 'Good afternoon';
  return 'Good evening';
}

double clamp01(double v) => math.min(1, math.max(0, v));
