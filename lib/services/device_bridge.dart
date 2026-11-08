import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../models.dart';

class DeviceBridge {
  static const MethodChannel _channel = MethodChannel('emo/device');

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  Future<DeviceState> getState() async {
    if (!isAndroid) {
      return DeviceState.unsupported('Device control runs on Android.');
    }
    try {
      final raw = await _channel.invokeMapMethod<dynamic, dynamic>('getState');
      if (raw == null) {
        return DeviceState.unsupported('Device state is unavailable.');
      }
      return DeviceState.fromMap(raw);
    } on PlatformException catch (e) {
      return DeviceState.unsupported(e.message ?? 'Device state is unavailable.');
    } catch (e) {
      return DeviceState.unsupported('Device state is unavailable.');
    }
  }

  Future<BridgeResult> _call(String method, [Map<String, dynamic>? args]) async {
    if (!isAndroid) {
      return const BridgeResult(
        ok: false,
        message: 'Device control is only available on Android.',
      );
    }
    try {
      final raw = await _channel.invokeMethod<dynamic>(method, args);
      return BridgeResult.fromMap(raw);
    } on PlatformException catch (e) {
      return BridgeResult(ok: false, message: e.message ?? 'That did not work.');
    } catch (e) {
      return const BridgeResult(ok: false, message: 'That did not work.');
    }
  }

  Future<BridgeResult> setTorch(bool on) => _call('setTorch', {'on': on});

  Future<BridgeResult> setWifi(bool on) => _call('setWifi', {'on': on});

  Future<BridgeResult> setBluetooth(bool on) => _call('setBluetooth', {'on': on});

  Future<BridgeResult> setDnd(String mode) => _call('setDnd', {'mode': mode});

  Future<BridgeResult> setBrightness(double value) =>
      _call('setBrightness', {'value': value});

  Future<BridgeResult> setVolume(String stream, double value) =>
      _call('setVolume', {'stream': stream, 'value': value});

  Future<BridgeResult> openPanel(String kind) => _call('openPanel', {'kind': kind});

  Future<BridgeResult> openApp(String query) => _call('openApp', {'query': query});

  Future<BridgeResult> openUrl(String url) => _call('openUrl', {'url': url});

  Future<BridgeResult> dial(String number) => _call('dial', {'number': number});

  Future<BridgeResult> composeSms(String number, String body) =>
      _call('composeSms', {'number': number, 'body': body});

  Future<BridgeResult> findContact(String name) =>
      _call('findContact', {'name': name});

  Future<BridgeResult> globalAction(String action) =>
      _call('globalAction', {'action': action});

  Future<BridgeResult> swipe(String direction) =>
      _call('swipe', {'direction': direction});

  Future<BridgeResult> dismissNotifications() => _call('dismissNotifications');

  Future<BridgeResult> requestPermission(String name) =>
      _call('requestPermission', {'name': name});

  Future<bool> notifyReply(String body, {String title = 'Emo'}) async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'notifyReply',
            {'title': title, 'body': body},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> notifyUpdate({
    required String version,
    required String url,
    String notes = '',
  }) async {
    if (!isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'notifyUpdate',
            {'version': version, 'url': url, 'notes': notes},
          ) ??
          false;
    } catch (_) {
      return false;
    }
  }

  Future<String> appVersion() async {
    if (!isAndroid) return '';
    try {
      return await _channel.invokeMethod<String>('appVersion') ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<BridgeResult> syncRoutines(List<Routine> routines) => _call(
        'syncRoutines',
        {'json': _encodeRoutines(routines)},
      );

  Future<List<AppNotification>> getNotifications() async {
    if (!isAndroid) return const [];
    try {
      final raw = await _channel.invokeListMethod<dynamic>('getNotifications');
      return (raw ?? [])
          .whereType<Map>()
          .map(AppNotification.fromMap)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<String>> getInstalledApps() async {
    if (!isAndroid) return const [];
    try {
      final raw = await _channel.invokeListMethod<dynamic>('getInstalledApps');
      return (raw ?? [])
          .whereType<Map>()
          .map((e) => (e['label'] as String?) ?? '')
          .where((label) => label.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<RoutineEvent>> consumeRoutineEvents() async {
    if (!isAndroid) return const [];
    try {
      final raw = await _channel.invokeListMethod<dynamic>('consumeRoutineEvents');
      return (raw ?? []).whereType<Map>().map(RoutineEvent.fromMap).toList();
    } catch (_) {
      return const [];
    }
  }

  String _encodeRoutines(List<Routine> routines) {
    final buffer = StringBuffer('[');
    for (var i = 0; i < routines.length; i++) {
      if (i > 0) buffer.write(',');
      buffer.write(_json(routines[i].toNativeJson()));
    }
    buffer.write(']');
    return buffer.toString();
  }

  String _json(Object? value) {
    if (value == null) return 'null';
    if (value is String) {
      final escaped = value
          .replaceAll('\\', '\\\\')
          .replaceAll('"', '\\"')
          .replaceAll('\n', '\\n')
          .replaceAll('\r', '\\r');
      return '"$escaped"';
    }
    if (value is num || value is bool) return value.toString();
    if (value is List) return '[${value.map(_json).join(',')}]';
    if (value is Map) {
      return '{${value.entries.map((e) => '"${e.key}":${_json(e.value)}').join(',')}}';
    }
    return '"$value"';
  }
}
