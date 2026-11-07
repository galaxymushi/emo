import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/emo_icons.dart';
import '../widgets/feedback.dart';
import '../widgets/glass.dart';

class ControlCenterScreen extends StatefulWidget {
  const ControlCenterScreen({super.key, required this.state});

  final AppState state;

  @override
  State<ControlCenterScreen> createState() => _ControlCenterScreenState();
}

class _ControlCenterScreenState extends State<ControlCenterScreen> {
  AppState get state => widget.state;

  late double _brightness = state.device.brightness;
  late double _media = state.device.volumeMusic;
  late double _ring = state.device.volumeRing;
  late double _alarm = state.device.volumeAlarm;
  bool _dragging = false;

  @override
  void didUpdateWidget(covariant ControlCenterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_dragging) {
      _brightness = state.device.brightness;
      _media = state.device.volumeMusic;
      _ring = state.device.volumeRing;
      _alarm = state.device.volumeAlarm;
    }
  }

  Future<void> _tile(String key, {String? panel}) async {
    if (panel != null) {
      await state.bridge.openPanel(panel);
      return;
    }
    final result = await state.quickAction(key);
    if (!mounted) return;
    if (result.needs == 'policy') {
      showPermissionSheet(context, state, 'policy');
      return;
    }
    emoSnack(
      context,
      result.message.isEmpty ? 'Done' : result.message,
      icon: result.ok ? Icons.check_circle_outline_rounded : Icons.open_in_new_rounded,
      color: result.ok ? EmoColors.success : EmoColors.blue,
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = state.device;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              EmoSizes.page,
              6,
              EmoSizes.page,
              40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                PageHeader(
                  title: 'Control center',
                  subtitle: 'Every switch, one place',
                  padding: const EdgeInsets.only(bottom: 18),
                  leading: GlassIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                    size: 42,
                  ),
                  trailing: GlassIconButton(
                    icon: Icons.refresh_rounded,
                    size: 42,
                    onTap: () => state.refreshDevice(),
                  ),
                ),
                _tileGrid(d),
                const SizedBox(height: 24),
                SectionTitle(
                  title: 'Screen & sound',
                  trailing: Text(
                    d.canWriteSettings ? 'System wide' : 'Emo window',
                    style: emoLabel(size: 9.5),
                  ),
                ),
                GlassSurface(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconBadge(
                            icon: Icons.brightness_6_rounded,
                            size: 40,
                            active: true,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Brightness',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                Text(
                                  d.canWriteSettings
                                      ? 'Applies to the whole phone'
                                      : 'Applies while Emo is open',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${(_brightness * 100).round()}%',
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: EmoColors.blueInk,
                            ),
                          ),
                        ],
                      ),
                      Slider(
                        value: _brightness.clamp(0.02, 1.0),
                        min: 0.02,
                        max: 1,
                        onChanged: (v) => setState(() {
                          _dragging = true;
                          _brightness = v;
                        }),
                        onChangeEnd: (v) async {
                          await state.bridge.setBrightness(v);
                          await state.refreshDevice();
                          if (mounted) setState(() => _dragging = false);
                        },
                      ),
                      if (!d.canWriteSettings)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                size: 14,
                                color: EmoColors.warning,
                              ),
                              const SizedBox(width: 6),
                              const Expanded(
                                child: Text(
                                  'Allow system settings to change it everywhere.',
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: EmoColors.muted,
                                  ),
                                ),
                              ),
                              Pressable(
                                onTap: () => showPermissionSheet(
                                  context,
                                  state,
                                  'write_settings',
                                ),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    'Allow',
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      color: EmoColors.blue,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Divider(height: 8),
                      _VolumeRow(
                        icon: Icons.music_note_rounded,
                        label: 'Media',
                        value: _media,
                        onChanged: (v) {
                          _dragging = true;
                          setState(() => _media = v);
                        },
                        onEnd: (v) async {
                          await state.bridge.setVolume('music', v);
                          await state.refreshDevice();
                          if (mounted) setState(() => _dragging = false);
                        },
                      ),
                      _VolumeRow(
                        icon: Icons.notifications_active_outlined,
                        label: 'Ring',
                        value: _ring,
                        onChanged: (v) {
                          _dragging = true;
                          setState(() => _ring = v);
                        },
                        onEnd: (v) async {
                          await state.bridge.setVolume('ring', v);
                          await state.refreshDevice();
                          if (mounted) setState(() => _dragging = false);
                        },
                      ),
                      _VolumeRow(
                        icon: Icons.alarm_rounded,
                        label: 'Alarm',
                        value: _alarm,
                        onChanged: (v) {
                          _dragging = true;
                          setState(() => _alarm = v);
                        },
                        onEnd: (v) async {
                          await state.bridge.setVolume('alarm', v);
                          await state.refreshDevice();
                          if (mounted) setState(() => _dragging = false);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GlassSurface(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      IconBadge(
                        icon: Icons.notifications_none_rounded,
                        size: 42,
                        active: d.notificationCount > 0,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifications',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 1),
                            Text(
                              !d.notificationAccess
                                  ? 'Access not granted'
                                  : (d.notificationCount == 0
                                      ? 'Nothing waiting'
                                      : '${d.notificationCount} waiting'),
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      GhostButton(
                        label: !d.notificationAccess
                            ? 'Allow'
                            : 'Clear all',
                        height: 38,
                        onTap: () {
                          if (!d.notificationAccess) {
                            showPermissionSheet(
                              context,
                              state,
                              'notification_access',
                            );
                          } else {
                            _clearNotifications();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: EmoColors.faint,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Wi-Fi, Bluetooth and airplane mode open Android’s own panels. Android does not allow background apps to switch them silently.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 11,
                              height: 1.45,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _clearNotifications() async {
    final result = await state.bridge.dismissNotifications();
    await state.refreshDevice();
    if (!mounted) return;
    emoSnack(
      context,
      result.ok ? 'Notifications cleared' : result.message,
      icon: result.ok
          ? Icons.notifications_off_outlined
          : Icons.error_outline_rounded,
      color: result.ok ? EmoColors.success : EmoColors.warning,
    );
  }

  Widget _tileGrid(DeviceState device) {
    final tiles = [
      _Tile(
        key: 'wifi',
        label: 'Wi-Fi',
        sub: device.wifiConnected ? 'Connected' : 'Off',
        icon: Icons.wifi_rounded,
        active: device.wifiConnected,
        loading: state.pendingQuick.contains('wifi'),
      ),
      _Tile(
        key: 'bluetooth',
        label: 'Bluetooth',
        sub: device.bluetoothOn ? 'On' : 'Off',
        icon: Icons.bluetooth_rounded,
        active: device.bluetoothOn,
        loading: state.pendingQuick.contains('bluetooth'),
      ),
      _Tile(
        key: 'torch',
        label: 'Torch',
        sub: device.torchOn ? 'On' : 'Off',
        icon: Icons.flashlight_on_rounded,
        active: device.torchOn,
        loading: state.pendingQuick.contains('torch'),
      ),
      _Tile(
        key: 'dnd',
        label: 'Do Not Disturb',
        sub: device.dndOn ? device.dndLabel : 'Off',
        icon: Icons.do_not_disturb_on_rounded,
        active: device.dndOn,
        loading: state.pendingQuick.contains('dnd'),
      ),
      _Tile(
        key: 'airplane',
        label: 'Airplane mode',
        sub: 'System panel',
        icon: Icons.airplanemode_active_rounded,
        panel: 'airplane',
      ),
      _Tile(
        key: 'data',
        label: 'Mobile data',
        sub: 'Network panel',
        icon: Icons.signal_cellular_alt_rounded,
        panel: 'data',
      ),
      _Tile(
        key: 'location',
        label: 'Location',
        sub: 'System panel',
        icon: Icons.location_on_outlined,
        panel: 'location',
      ),
      _Tile(
        key: 'battery',
        label: 'Battery saver',
        sub: 'System panel',
        icon: Icons.battery_saver_rounded,
        panel: 'battery',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: tiles.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 11,
        crossAxisSpacing: 11,
        childAspectRatio: 1.28,
      ),
      itemBuilder: (context, index) {
        final tile = tiles[index];
        return GlassSurface(
          radius: 22,
          padding: const EdgeInsets.all(14),
          onTap: () => _tile(tile.key, panel: tile.panel),
          gradient: tile.active
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xF5FFFFFF), Color(0xE2ECF7FF)],
                )
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(
                    icon: tile.icon,
                    active: tile.active,
                    size: 36,
                    radius: 12,
                  ),
                  const Spacer(),
                  if (tile.loading)
                    const SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.8,
                        valueColor: AlwaysStoppedAnimation(EmoColors.blue),
                      ),
                    )
                  else if (tile.panel != null)
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 12,
                      color: EmoColors.faint.withValues(alpha: 0.9),
                    )
                  else
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tile.active
                            ? EmoColors.blue
                            : EmoColors.ink.withValues(alpha: 0.12),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                tile.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: EmoColors.ink,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                tile.sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: tile.active ? EmoColors.blue : EmoColors.muted,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Tile {
  const _Tile({
    required this.key,
    required this.label,
    required this.sub,
    required this.icon,
    this.active = false,
    this.loading = false,
    this.panel,
  });

  final String key;
  final String label;
  final String sub;
  final IconData icon;
  final bool active;
  final bool loading;
  final String? panel;
}

class _VolumeRow extends StatelessWidget {
  const _VolumeRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
    required this.onEnd,
  });

  final IconData icon;
  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 17, color: EmoColors.muted),
          const SizedBox(width: 10),
          SizedBox(
            width: 46,
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: EmoColors.inkSoft,
              ),
            ),
          ),
          Expanded(
            child: Slider(
              value: value.clamp(0.0, 1.0),
              onChanged: onChanged,
              onChangeEnd: onEnd,
            ),
          ),
          SizedBox(
            width: 34,
            child: Text(
              '${(value * 100).round()}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: EmoColors.muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
