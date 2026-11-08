import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../services/cloud_brain.dart';
import '../services/memory_store.dart';
import '../services/voice_service.dart';
import '../theme.dart';
import '../widgets/emo_icons.dart';
import '../widgets/feedback.dart';
import '../widgets/glass.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.state});

  final AppState state;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  AppState get state => widget.state;

  late double _rate = state.speechRate;

  static const _androidNames = {
    26: '8.0',
    27: '8.1',
    28: '9',
    29: '10',
    30: '11',
    31: '12',
    32: '12L',
    33: '13',
    34: '14',
    35: '15',
    36: '16',
  };

  void _openAccess(String need) => showPermissionSheet(context, state, need);

  Future<void> _openVoiceSheet() async {
    await state.ensureVoices();
    if (!mounted) return;
    await showEmoSheet<void>(
      context,
      builder: (_) => _VoiceSheet(state: state),
    );
  }

  Future<void> _openCloudSheet() async {
    await showEmoSheet<void>(
      context,
      builder: (_) => _CloudSheet(state: state),
    );
  }

  Future<void> _editOwnerName() async {
    final controller = TextEditingController(text: state.ownerName);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('What should Emo call you?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 24,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(hintText: 'Boss'),
          onSubmitted: (text) => Navigator.of(context).pop(text),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value != null) await state.setOwnerName(value);
  }

  Future<void> _openMemorySheet() async {
    await showEmoSheet<void>(
      context,
      builder: (_) => _MemorySheet(state: state),
    );
  }

  Future<void> _toggleCloud(bool value) async {
    await state.setCloudEnabled(value);
    if (value && !state.cloud.configured && mounted) {
      await _openCloudSheet();
    }
  }

  Future<void> _toggleReplyAlerts(bool value) async {
    if (value && !state.device.notificationPermission) {
      final granted = await state.grantAccess('notifications');
      if (!granted) {
        if (!mounted) return;
        emoSnack(
          context,
          'Allow notifications in Android settings first.',
          icon: Icons.notifications_off_outlined,
          color: EmoColors.warning,
        );
        return;
      }
    }
    await state.setReplyNotifications(value);
  }

  Future<void> _toggleUpdateAlerts(bool value) async {
    if (value && !state.device.notificationPermission) {
      final granted = await state.grantAccess('notifications');
      if (!granted) {
        if (!mounted) return;
        emoSnack(
          context,
          'Allow notifications in Android settings first.',
          icon: Icons.notifications_off_outlined,
          color: EmoColors.warning,
        );
        return;
      }
    }
    await state.setUpdateNotifications(value);
  }

  Future<void> _openShizuku() async {
    final result = state.device.shizukuInstalled
        ? await state.bridge.openApp('Shizuku')
        : await state.bridge.openUrl('https://shizuku.rikka.app/');
    if (!mounted) return;
    if (!result.ok) {
      emoSnack(
        context,
        'Shizuku is optional — Emo works without it.',
        icon: Icons.info_outline_rounded,
      );
    }
  }

  Future<void> _confirmClearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Clear activity history?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Every recorded action will be removed from this phone. Your routines stay.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Keep',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w700,
                        color: EmoColors.muted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text(
                      'Clear',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w800,
                        color: EmoColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await state.clearHistory();
    if (!mounted) return;
    emoSnack(context, 'Activity history cleared', icon: Icons.delete_outline_rounded);
  }

  @override
  Widget build(BuildContext context) {
    final d = state.device;
    final android = _androidNames[d.androidSdk] ?? '${d.androidSdk}';

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          EmoSizes.page,
          12,
          EmoSizes.page,
          EmoSizes.navSpace,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PageHeader(
              title: 'Settings',
              subtitle: 'Access, voice and privacy',
              padding: const EdgeInsets.only(bottom: 18),
              leading: const IconBadge(
                icon: Icons.tune_rounded,
                active: true,
                size: 44,
              ),
              trailing: GlassIconButton(
                icon: Icons.refresh_rounded,
                size: 44,
                onTap: state.refreshDevice,
              ),
            ),
            _DeviceCard(device: d, android: android),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Access & control'),
            _Group(
              children: [
                _SettingRow(
                  icon: Icons.accessibility_new_rounded,
                  title: 'Accessibility service',
                  subtitle: d.accessibility
                      ? 'On — Emo can go back, home and scroll'
                      : 'Off — unlock navigation and gestures',
                  trailing: _stateChip(
                    ready: d.accessibility,
                    readyLabel: 'On',
                  ),
                  onTap: () => _openAccess('accessibility'),
                ),
                _SettingRow(
                  icon: Icons.notifications_active_outlined,
                  title: 'Notification access',
                  subtitle: d.notificationAccess
                      ? 'Allowed — Emo can read and clear alerts'
                      : 'Needed to read what is waiting',
                  trailing: _stateChip(
                    ready: d.notificationAccess,
                    readyLabel: 'Allowed',
                  ),
                  onTap: () => _openAccess('notification_access'),
                ),
                _SettingRow(
                  icon: Icons.do_not_disturb_on_outlined,
                  title: 'Do Not Disturb access',
                  subtitle: d.dndAccess
                      ? 'Allowed — quiet mode is available'
                      : 'Needed to change quiet mode',
                  trailing: _stateChip(ready: d.dndAccess, readyLabel: 'Allowed'),
                  onTap: () => _openAccess('policy'),
                ),
                _SettingRow(
                  icon: Icons.display_settings_rounded,
                  title: 'Modify system settings',
                  subtitle: d.canWriteSettings
                      ? 'Allowed — brightness sticks everywhere'
                      : 'Needed for brightness outside Emo',
                  trailing: _stateChip(
                    ready: d.canWriteSettings,
                    readyLabel: 'Allowed',
                  ),
                  onTap: () => _openAccess('write_settings'),
                ),
                _SettingRow(
                  icon: Icons.extension_rounded,
                  title: 'Shizuku',
                  subtitle: d.shizukuInstalled
                      ? 'Installed — optional deeper control'
                      : 'Not installed — Emo works without it',
                  trailing: StatusChip(
                    label: d.shizukuInstalled ? 'Installed' : 'Optional',
                    color: d.shizukuInstalled
                        ? EmoColors.blue
                        : EmoColors.faint,
                    compact: true,
                  ),
                  onTap: _openShizuku,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Voice'),
            _Group(
              children: [
                _SettingRow(
                  icon: Icons.record_voice_over_rounded,
                  title: 'Spoken replies',
                  subtitle: 'Emo reads every answer aloud',
                  trailing: EmoSwitch(
                    value: state.voiceReplies,
                    onChanged: state.setVoiceReplies,
                  ),
                ),
                _RateRow(
                  rate: _rate,
                  onChanged: (value) => setState(() => _rate = value),
                  onEnd: (value) async {
                    await state.setSpeechRate(value);
                  },
                ),
                _SettingRow(
                  icon: Icons.graphic_eq_rounded,
                  title: 'Voice',
                  subtitle: state.voice.currentVoice == null
                      ? "Using your phone's default voice"
                      : '${state.voiceLabel} · ${state.voice.currentVoice!.isNatural ? 'internet' : 'offline'}',
                  trailing: const StatusChip(
                    label: 'Change',
                    color: EmoColors.blue,
                    compact: true,
                  ),
                  onTap: _openVoiceSheet,
                ),
                _SettingRow(
                  icon: Icons.translate_rounded,
                  title: 'Voice language',
                  subtitle: 'Commands are recognized in US English',
                  trailing: const StatusChip(
                    label: 'English (US)',
                    color: EmoColors.blue,
                    compact: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Emo'),
            _Group(
              children: [
                _SettingRow(
                  icon: Icons.badge_outlined,
                  title: 'What Emo calls you',
                  subtitle: state.ownerName,
                  trailing: const StatusChip(
                    label: 'Edit',
                    color: EmoColors.blue,
                    compact: true,
                  ),
                  onTap: _editOwnerName,
                ),
                _SettingRow(
                  icon: Icons.waving_hand_outlined,
                  title: 'Greet me on launch',
                  subtitle: state.greetOnLaunch
                      ? 'Emo says hello and offers help when the app opens'
                      : 'Emo waits for you to speak first',
                  trailing: EmoSwitch(
                    value: state.greetOnLaunch,
                    onChanged: state.setGreetOnLaunch,
                  ),
                ),
                _SettingRow(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Memory',
                  subtitle: state.memory.isEmpty
                      ? 'Nothing remembered yet — say “remember that …”'
                      : '${state.memory.count} ${state.memory.count == 1 ? 'fact' : 'facts'} kept on this phone',
                  trailing: const StatusChip(
                    label: 'View',
                    color: EmoColors.blue,
                    compact: true,
                  ),
                  onTap: _openMemorySheet,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Notifications'),
            _Group(
              children: [
                _SettingRow(
                  icon: Icons.mark_chat_unread_outlined,
                  title: 'Reply notifications',
                  subtitle: state.replyNotifications
                      ? 'Notify when an answer arrives while Emo is in the background'
                      : 'Off — answers stay in the chat',
                  trailing: EmoSwitch(
                    value: state.replyNotifications,
                    onChanged: _toggleReplyAlerts,
                  ),
                ),
                _SettingRow(
                  icon: Icons.system_update_alt_rounded,
                  title: 'Update notifications',
                  subtitle: state.updateNotifications
                      ? 'Tell me when a newer Emo APK is released'
                      : 'Off — no update alerts',
                  trailing: EmoSwitch(
                    value: state.updateNotifications,
                    onChanged: _toggleUpdateAlerts,
                  ),
                ),
                _SettingRow(
                  icon: Icons.download_rounded,
                  title: state.availableUpdate != null
                      ? 'Emo ${state.availableUpdate!.version} is ready'
                      : 'App updates',
                  subtitle: state.checkingUpdate
                      ? 'Checking for updates…'
                      : state.updateError ??
                          (state.availableUpdate != null
                              ? 'Tap to download the latest APK'
                              : state.appVersion.isEmpty
                                  ? 'Check the latest release'
                                  : 'You are on Emo ${state.appVersion}'),
                  trailing: StatusChip(
                    label: state.availableUpdate != null
                        ? 'Get'
                        : (state.checkingUpdate ? '…' : 'Check'),
                    color: state.availableUpdate != null
                        ? EmoColors.success
                        : EmoColors.muted,
                    compact: true,
                  ),
                  onTap: state.availableUpdate != null
                      ? state.openUpdate
                      : () => state.checkForUpdates(manual: true),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Intelligence'),
            _Group(
              children: [
                _SettingRow(
                  icon: Icons.psychology_alt_outlined,
                  title: 'Cloud brain',
                  subtitle: state.cloudEnabled
                      ? (state.cloud.configured
                          ? 'Understands free-form requests and answers questions'
                          : 'Needs an API key to start')
                      : 'Off — Emo uses only its built-in commands',
                  trailing: EmoSwitch(
                    value: state.cloudEnabled,
                    onChanged: _toggleCloud,
                  ),
                ),
                _SettingRow(
                  icon: Icons.cloud_outlined,
                  title: 'Cloud setup',
                  subtitle: state.cloud.configured
                      ? '${state.cloudProviderName} · ${state.cloud.model}'
                      : 'Add an API key to unlock free-form understanding',
                  trailing: StatusChip(
                    label: state.cloud.configured ? 'Ready' : 'Set up',
                    color: state.cloud.configured
                        ? EmoColors.blue
                        : EmoColors.warning,
                    compact: true,
                  ),
                  onTap: _openCloudSheet,
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Permissions'),
            _Group(
              children: [
                _PermissionRow(
                  state: state,
                  icon: Icons.camera_alt_outlined,
                  title: 'Camera',
                  subtitle: 'Required for the torch',
                  granted: d.cameraPermission,
                  need: 'camera',
                ),
                _PermissionRow(
                  state: state,
                  icon: Icons.mic_none_rounded,
                  title: 'Microphone',
                  subtitle: 'For voice commands',
                  granted: d.microphonePermission,
                  need: 'microphone',
                ),
                _PermissionRow(
                  state: state,
                  icon: Icons.person_search_outlined,
                  title: 'Contacts',
                  subtitle: 'Match names for calls and messages',
                  granted: d.contactsPermission,
                  need: 'contacts',
                ),
                _PermissionRow(
                  state: state,
                  icon: Icons.notifications_none_rounded,
                  title: 'Notification alerts',
                  subtitle: 'Post routine and status alerts',
                  granted: d.notificationPermission,
                  need: 'notifications',
                ),
              ],
            ),
            const SizedBox(height: 24),
            const SectionTitle(title: 'Privacy & data'),
            _Group(
              children: [
                _SettingRow(
                  icon: Icons.history_rounded,
                  title: 'Keep activity history',
                  subtitle: state.keepHistory
                      ? 'Actions are saved between sessions'
                      : 'Saved history is off',
                  trailing: EmoSwitch(
                    value: state.keepHistory,
                    onChanged: state.setKeepHistory,
                  ),
                ),
                _SettingRow(
                  icon: Icons.delete_sweep_outlined,
                  title: 'Clear activity history',
                  subtitle: 'Remove every recorded action',
                  trailing: StatusChip(
                    label: '${state.activity.length}',
                    color: EmoColors.muted,
                    compact: true,
                  ),
                  onTap: state.activity.isEmpty ? null : _confirmClearHistory,
                ),
              ],
            ),
            const SizedBox(height: 14),
            GlassSurface(
              radius: 20,
              blur: 12,
              padding: const EdgeInsets.fromLTRB(15, 13, 15, 13),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xDEFFFFFF), Color(0xC2EFF7FF)],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.shield_outlined,
                    size: 17,
                    color: EmoColors.blue,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      state.cloudReady
                          ? 'Offline commands never leave your phone. With Cloud brain on, only requests Emo cannot handle offline, the last few chat messages and basic device state are sent to your chosen provider.'
                          : 'Emo runs on this phone. Your commands, messages and notifications are never uploaded.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 11.5,
                            height: 1.5,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            Center(
              child: Column(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: EmoColors.faint,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    state.appVersion.isEmpty
                        ? 'Emo · built for Android'
                        : 'Emo ${state.appVersion} · built for Android',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: EmoColors.faint,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stateChip({required bool ready, required String readyLabel}) {
    return StatusChip(
      label: ready ? readyLabel : 'Needed',
      color: ready ? EmoColors.success : EmoColors.warning,
      compact: true,
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.device, required this.android});

  final DeviceState device;
  final String android;

  @override
  Widget build(BuildContext context) {
    final available = device.available;
    return GlassSurface(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFFFF), Color(0xFFF0F7FF)],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Icons.phone_iphone_rounded,
                active: true,
                size: 50,
                radius: 17,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      available ? device.deviceName : 'This phone',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      available
                          ? '${device.manufacturer.isEmpty ? 'Android' : device.manufacturer} · Android $android'
                          : (device.error ?? 'Device bridge unavailable'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              StatusChip(
                label: available ? 'Ready' : 'Limited',
                color: available ? EmoColors.success : EmoColors.warning,
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              _MetaPill(
                icon: Icons.battery_5_bar_rounded,
                label: available ? '${device.battery}%' : '—',
              ),
              const SizedBox(width: 8),
              _MetaPill(
                icon: Icons.wifi_rounded,
                label: !available
                    ? '—'
                    : (device.wifiConnected ? 'Wi-Fi' : 'No Wi-Fi'),
              ),
              const SizedBox(width: 8),
              _MetaPill(
                icon: Icons.shield_outlined,
                label: device.accessibility ? 'Access on' : 'Setup',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: EmoColors.blue.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: EmoColors.blue),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: EmoColors.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) rows.add(const Divider(height: 1));
    }
    return GlassSurface(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 2),
      child: Column(children: rows),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          IconBadge(icon: icon, size: 38, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: EmoColors.ink,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: EmoColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing!],
          if (onTap != null)
            const Padding(
              padding: EdgeInsets.only(left: 3),
              child: Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: EmoColors.faint,
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Pressable(onTap: onTap, scale: 0.99, child: row);
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({
    required this.rate,
    required this.onChanged,
    required this.onEnd,
  });

  final double rate;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onEnd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 11, bottom: 4),
      child: Column(
        children: [
          Row(
            children: [
              const IconBadge(
                icon: Icons.speed_rounded,
                size: 38,
                radius: 12,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Speech rate',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: EmoColors.ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'How fast Emo talks',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: EmoColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(rate * 100).round()}%',
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: EmoColors.blueInk,
                ),
              ),
            ],
          ),
          Slider(
            value: rate.clamp(0.25, 1.0),
            min: 0.25,
            max: 1,
            onChanged: onChanged,
            onChangeEnd: onEnd,
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.state,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.granted,
    required this.need,
  });

  final AppState state;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool granted;
  final String need;

  @override
  Widget build(BuildContext context) {
    return _SettingRow(
      icon: icon,
      title: title,
      subtitle: subtitle,
      trailing: granted
          ? const StatusChip(
              label: 'Allowed',
              color: EmoColors.success,
              compact: true,
            )
          : Pressable(
              onTap: () => showPermissionSheet(context, state, need),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: EmoColors.blue.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: EmoColors.blue.withValues(alpha: 0.16),
                  ),
                ),
                child: const Text(
                  'Allow',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: EmoColors.blue,
                  ),
                ),
              ),
            ),
      onTap: granted ? null : () => showPermissionSheet(context, state, need),
    );
  }
}

class _MemorySheet extends StatelessWidget {
  const _MemorySheet({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final facts = state.memory.facts;
        return SheetShell(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Emo’s memory', style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                'Facts you asked Emo to keep about you. They stay on this phone and are sent only when Emo needs context to answer.',
                style: theme.textTheme.bodySmall?.copyWith(height: 1.45),
              ),
              const SizedBox(height: 14),
              if (facts.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Text(
                    'Nothing here yet. Say “remember that I like tea” or “my name is …”.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: EmoColors.muted,
                      height: 1.45,
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    for (final fact in facts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF2F7FF),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  fact.text,
                                  style: theme.textTheme.bodyMedium
                                      ?.copyWith(height: 1.35),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Forget this',
                                onPressed: () =>
                                    state.removeMemoryFact(fact.id),
                                icon: const Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: EmoColors.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${facts.length} of ${MemoryStore.maxFacts} remembered',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  TextButton(
                    onPressed:
                        facts.isEmpty ? null : () => state.clearMemory(),
                    child: const Text('Forget all'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CloudSheet extends StatefulWidget {
  const _CloudSheet({required this.state});

  final AppState state;

  @override
  State<_CloudSheet> createState() => _CloudSheetState();
}

class _CloudSheetState extends State<_CloudSheet> {
  late String _providerId;
  late final TextEditingController _key;
  late final TextEditingController _model;
  late final TextEditingController _endpoint;

  bool _obscure = true;
  bool _testing = false;
  bool _saving = false;
  String? _status;
  bool _statusOk = false;

  AppState get state => widget.state;
  CloudProvider get _provider => CloudProvider.byId(_providerId);

  @override
  void initState() {
    super.initState();
    _providerId = state.cloudProviderId;
    _key = TextEditingController(text: state.cloud.apiKey);
    _model = TextEditingController(text: state.cloud.model);
    _endpoint = TextEditingController(
      text: _provider.isCustom ? state.cloud.endpoint : '',
    );
  }

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    _endpoint.dispose();
    super.dispose();
  }

  void _selectProvider(CloudProvider provider) {
    setState(() {
      _providerId = provider.id;
      _model.text = provider.model;
      if (!provider.isCustom) _endpoint.clear();
      _status = null;
    });
  }

  Future<void> _test() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _testing = true;
      _status = null;
    });
    final error = await state.testCloudConfig(
      providerId: _providerId,
      apiKey: _key.text,
      model: _model.text,
      endpoint: _endpoint.text,
    );
    if (!mounted) return;
    setState(() {
      _testing = false;
      _statusOk = error == null;
      _status = error ?? 'Connection works. Emo Cloud is ready.';
    });
  }

  Future<void> _save() async {
    if (_provider.isCustom) {
      final endpoint = _endpoint.text.trim();
      if (!endpoint.startsWith('https://') ||
          !endpoint.contains('/chat/completions')) {
        setState(() {
          _statusOk = false;
          _status = 'Enter an https:// chat completions endpoint.';
        });
        return;
      }
    }
    setState(() => _saving = true);
    await state.saveCloudConfig(
      providerId: _providerId,
      apiKey: _key.text,
      model: _model.text,
      endpoint: _endpoint.text,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = _provider;
    return SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cloud brain', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Emo sends only requests it cannot handle offline, the last few chat messages for context, and basic device state. Contacts, messages and notifications stay on this phone.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final option in CloudProvider.all)
                _ProviderChip(
                  label: option.name,
                  selected: option.id == _providerId,
                  onTap: () => _selectProvider(option),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _CloudField(
            label: 'API key',
            controller: _key,
            hint: 'Paste your API key',
            obscure: _obscure,
            suffix: IconButton(
              onPressed: () => setState(() => _obscure = !_obscure),
              icon: Icon(
                _obscure
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 19,
                color: EmoColors.muted,
              ),
            ),
          ),
          _CloudField(
            label: 'Model',
            controller: _model,
            hint: provider.model.isEmpty ? 'model name' : provider.model,
          ),
          if (provider.isCustom)
            _CloudField(
              label: 'Endpoint',
              controller: _endpoint,
              hint: 'https://…/chat/completions',
              keyboardType: TextInputType.url,
            ),
          if (provider.keyUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: TextButton.icon(
                onPressed: () => state.bridge.openUrl(provider.keyUrl),
                icon: const Icon(Icons.open_in_new_rounded, size: 15),
                label: Text('Get a ${provider.name} API key'),
                style: TextButton.styleFrom(
                  foregroundColor: EmoColors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  textStyle: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (_status != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: (_statusOk ? EmoColors.success : EmoColors.danger)
                    .withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_statusOk ? EmoColors.success : EmoColors.danger)
                      .withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                _status!,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 11.5,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: _statusOk ? EmoColors.success : EmoColors.danger,
                ),
              ),
            ),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: _testing || _saving ? null : _test,
                  style: TextButton.styleFrom(
                    foregroundColor: EmoColors.blue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Test connection',
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryButton(
                  label: _saving ? 'Saving…' : 'Save',
                  icon: Icons.check_rounded,
                  height: 48,
                  loading: _saving,
                  onTap: _saving ? null : _save,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Needs internet for cloud answers. The key is stored in this phone\u2019s Android keystore.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10.5,
                  height: 1.45,
                  color: EmoColors.faint,
                ),
          ),
        ],
      ),
    );
  }
}

class _ProviderChip extends StatelessWidget {
  const _ProviderChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: 0.96,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? EmoColors.blue.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected
                ? EmoColors.blue.withValues(alpha: 0.34)
                : Colors.white.withValues(alpha: 0.9),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            color: selected ? EmoColors.blueInk : EmoColors.muted,
          ),
        ),
      ),
    );
  }
}

class _CloudField extends StatelessWidget {
  const _CloudField({
    required this.label,
    required this.controller,
    required this.hint,
    this.obscure = false,
    this.suffix,
    this.keyboardType,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscure;
  final Widget? suffix;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: emoLabel(size: 9)),
          const SizedBox(height: 5),
          TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: keyboardType,
            autocorrect: false,
            enableSuggestions: false,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: EmoColors.ink,
            ),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: EmoColors.faint,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.66),
              suffixIcon: suffix,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 38,
                minHeight: 38,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide(
                  color: EmoColors.blue.withValues(alpha: 0.5),
                  width: 1.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceSheet extends StatelessWidget {
  const _VoiceSheet({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final english = state.voice.voices.where((v) => v.isEnglish).toList();
    final list = english.isEmpty ? state.voice.voices : english;
    final visible = list.length > 12 ? list.sublist(0, 12) : list;
    final current = state.voice.currentVoice;

    return SheetShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose a voice', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Natural voices sound more human but need an internet connection. Standard voices work offline.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 14),
          if (visible.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: EmoColors.blue.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                "This phone's text-to-speech engine didn't report any voices. Install voice data in Android Settings → System → Languages & input → Text-to-speech output.",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      height: 1.45,
                    ),
              ),
            )
          else
            for (var index = 0; index < visible.length; index++)
              _VoiceRow(
                voice: visible[index],
                index: index,
                selected: current != null &&
                    current.name == visible[index].name &&
                    current.locale == visible[index].locale,
                onPreview: () => state.voice.previewVoice(visible[index]),
                onSelect: () async {
                  await state.setEmoVoice(visible[index]);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
          const SizedBox(height: 6),
          Text(
            'Voices come from your phone. Install more in Android Settings → Text-to-speech.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10.5,
                  height: 1.45,
                  color: EmoColors.faint,
                ),
          ),
        ],
      ),
    );
  }
}

class _VoiceRow extends StatelessWidget {
  const _VoiceRow({
    required this.voice,
    required this.index,
    required this.selected,
    required this.onSelect,
    required this.onPreview,
  });

  final EmoVoice voice;
  final int index;
  final bool selected;
  final VoidCallback onSelect;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Pressable(
        onTap: onSelect,
        scale: 0.99,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 9, 8, 9),
          decoration: BoxDecoration(
            color: selected
                ? EmoColors.blue.withValues(alpha: 0.09)
                : Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? EmoColors.blue.withValues(alpha: 0.30)
                  : Colors.white.withValues(alpha: 0.9),
            ),
          ),
          child: Row(
            children: [
              IconBadge(
                icon: selected
                    ? Icons.check_rounded
                    : Icons.graphic_eq_rounded,
                active: selected,
                size: 34,
                radius: 11,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${voice.languageName} · Voice ${index + 1}'
                      '${voice.gender != null ? ' · ${voice.gender}' : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: selected ? EmoColors.blueInk : EmoColors.ink,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      voice.isNatural
                          ? 'Natural · needs internet'
                          : 'Standard · works offline',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: EmoColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onPreview,
                icon: const Icon(Icons.play_circle_outline_rounded),
                color: EmoColors.blue,
                iconSize: 26,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: 'Preview',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
