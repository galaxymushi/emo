import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/emo_icons.dart';
import '../widgets/feedback.dart';
import '../widgets/glass.dart';
import '../widgets/orb.dart';
import 'assistant_screen.dart';
import 'control_center_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.state});

  final AppState state;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();

  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 5200),
  )..repeat(reverse: true);

  bool _listening = false;
  String _partial = '';

  @override
  void dispose() {
    _controller.dispose();
    _float.dispose();
    super.dispose();
  }

  void _openAssistant({String? command, bool voice = false}) {
    _focus.unfocus();
    Navigator.of(context).push(
      emoRoute(
        AssistantScreen(
          state: widget.state,
          initialCommand: command,
          autoStartVoice: voice,
        ),
      ),
    );
  }

  void _sendText() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    _openAssistant(command: text);
  }

  Future<void> _toggleVoice() async {
    final voice = widget.state.voice;
    if (_listening) {
      await voice.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    voice.onListeningChanged = () {
      if (mounted) setState(() => _listening = voice.listening);
    };
    voice.onPartial = (text) {
      if (mounted) setState(() => _partial = text);
    };
    voice.onError = (message) {
      if (!mounted) return;
      setState(() => _listening = false);
      emoSnack(
        context,
        message,
        icon: Icons.mic_off_rounded,
        color: EmoColors.warning,
      );
    };
    voice.onFinal = (text) async {
      await voice.stop();
      if (!mounted) return;
      setState(() {
        _listening = false;
        _partial = '';
      });
      final command = text.trim();
      if (command.isEmpty) return;
      _openAssistant(command: command);
    };
    final started = await voice.start();
    if (!mounted) return;
    setState(() => _listening = started);
  }

  Future<void> _quick(String key) async {
    final result = await widget.state.quickAction(key);
    if (!mounted) return;
    if (result.needs != null) {
      if (result.needs == 'policy') {
        showPermissionSheet(context, widget.state, 'policy');
      } else {
        emoSnack(
          context,
          result.message,
          icon: Icons.open_in_new_rounded,
          color: EmoColors.blue,
        );
      }
      return;
    }
    emoSnack(
      context,
      result.message.isEmpty ? 'Done' : result.message,
      icon: result.ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
      color: result.ok ? EmoColors.success : EmoColors.warning,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final device = state.device;
    final now = DateTime.now();

    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(
          EmoSizes.page,
          12,
          EmoSizes.page,
          EmoSizes.navSpace,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(
              greeting: greetingFor(now),
              ready: device.available &&
                  device.accessibility &&
                  device.notificationAccess &&
                  device.dndAccess,
              onControlCenter: () => Navigator.of(context).push(
                emoRoute(ControlCenterScreen(state: state)),
              ),
            ),
            const SizedBox(height: 18),
            _MetaRow(device: device),
            const SizedBox(height: 6),
            AnimatedBuilder(
              animation: _float,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, -7 * Curves.easeInOut.transform(_float.value)),
                  child: child,
                );
              },
              child: SizedBox(
                height: 288,
                child: Center(
                  child: EmoOrb(
                    size: 204,
                    listening: _listening,
                    thinking: state.busy,
                    onTap: () {
                      if (_listening) {
                        _toggleVoice();
                      } else {
                        _openAssistant(voice: true);
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _listening
                  ? 'Listening'
                  : (state.busy ? 'Working on it' : 'Ask me anything'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              _listening
                  ? (_partial.isEmpty ? 'Speak now — I am listening.' : _partial)
                  : 'Voice, text, or a saved routine.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: EmoColors.muted,
                  ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: GlassSurface(
                    height: 58,
                    radius: 29,
                    blur: 14,
                    padding: const EdgeInsets.only(left: 18, right: 7),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            focusNode: _focus,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendText(),
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: EmoColors.ink,
                            ),
                            cursorColor: EmoColors.blue,
                            decoration: InputDecoration(
                              isDense: true,
                              border: InputBorder.none,
                              hintText: 'Tell Emo what to do…',
                              hintStyle: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                                color: EmoColors.faint.withValues(alpha: 0.95),
                              ),
                            ),
                          ),
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (context, value, _) {
                            final hasText = value.text.trim().isNotEmpty;
                            return AnimatedOpacity(
                              duration: const Duration(milliseconds: 180),
                              opacity: hasText ? 1 : 0.35,
                              child: Pressable(
                                onTap: hasText ? _sendText : null,
                                child: Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: hasText
                                        ? EmoGradients.primary
                                        : EmoGradients.primarySoft,
                                  ),
                                  child: Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 20,
                                    color: hasText
                                        ? Colors.white
                                        : EmoColors.blueInk,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                _MicButton(
                  listening: _listening,
                  onTap: _toggleVoice,
                ),
              ],
            ),
            const SizedBox(height: 26),
            SectionTitle(
              title: 'Quick controls',
              trailing: Pressable(
                onTap: () => Navigator.of(context).push(
                  emoRoute(ControlCenterScreen(state: state)),
                ),
                child: const Row(
                  children: [
                    Text(
                      'All controls',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: EmoColors.blue,
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: EmoColors.blue,
                    ),
                  ],
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _QuickTile(
                    icon: Icons.wifi_rounded,
                    label: 'Wi-Fi',
                    value: device.wifiConnected
                        ? 'Connected'
                        : (device.wifiEnabled ? 'On' : 'Off'),
                    active: device.wifiConnected,
                    loading: state.pendingQuick.contains('wifi'),
                    onTap: () => _quick('wifi'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickTile(
                    icon: Icons.bluetooth_rounded,
                    label: 'Bluetooth',
                    value: !device.bluetoothSupported
                        ? 'Unavailable'
                        : (device.bluetoothOn ? 'On' : 'Off'),
                    active: device.bluetoothOn,
                    loading: state.pendingQuick.contains('bluetooth'),
                    onTap: () => _quick('bluetooth'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickTile(
                    icon: Icons.flashlight_on_rounded,
                    label: 'Torch',
                    value: device.torchOn ? 'On' : 'Off',
                    active: device.torchOn,
                    loading: state.pendingQuick.contains('torch'),
                    onTap: () => _quick('torch'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuickTile(
                    icon: Icons.do_not_disturb_on_rounded,
                    label: 'DND',
                    value: device.dndOn ? device.dndLabel : 'Off',
                    active: device.dndOn,
                    loading: state.pendingQuick.contains('dnd'),
                    onTap: () => _quick('dnd'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            GlassSurface(
              padding: const EdgeInsets.all(16),
              onTap: () => Navigator.of(context).push(
                emoRoute(ControlCenterScreen(state: state)),
              ),
              child: Row(
                children: [
                  const IconBadge(
                    icon: Icons.grid_view_rounded,
                    active: true,
                    size: 44,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Control center',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Brightness, volume, connectivity and more',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: EmoColors.faint,
                    size: 22,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _NextRoutineCard(state: state),
            if (!device.accessibility ||
                !device.notificationAccess ||
                !device.dndAccess) ...[
              const SizedBox(height: 12),
              _SetupCard(state: state),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.ready,
    required this.onControlCenter,
  });

  final String greeting;
  final bool ready;
  final VoidCallback onControlCenter;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ready ? EmoColors.success : EmoColors.warning,
                      boxShadow: [
                        BoxShadow(
                          color: (ready ? EmoColors.success : EmoColors.warning)
                              .withValues(alpha: 0.45),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    ready ? 'EMO IS READY' : 'SETUP NEEDED',
                    style: emoLabel(size: 10),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Text(greeting, style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                'What should I handle?',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: EmoColors.muted,
                    ),
              ),
            ],
          ),
        ),
        GlassIconButton(
          icon: Icons.tune_rounded,
          onTap: onControlCenter,
          size: 46,
        ),
      ],
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.device});

  final DeviceState device;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetaPill(
          icon: device.charging
              ? Icons.bolt_rounded
              : Icons.battery_5_bar_rounded,
          label: device.battery >= 0 ? '${device.battery}%' : 'Battery —',
          color: device.battery <= 20 && device.battery >= 0
              ? EmoColors.danger
              : EmoColors.inkSoft,
        ),
        _MetaPill(
          icon: device.wifiConnected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
          label: device.wifiConnected ? 'Wi-Fi connected' : 'Wi-Fi off',
          color: EmoColors.inkSoft,
        ),
        if (device.dndOn)
          const _MetaPill(
            icon: Icons.dark_mode_rounded,
            label: 'Do Not Disturb',
            color: EmoColors.blueInk,
          ),
        if (device.notificationCount > 0)
          _MetaPill(
            icon: Icons.notifications_none_rounded,
            label: '${device.notificationCount} waiting',
            color: EmoColors.inkSoft,
          ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    this.color = EmoColors.inkSoft,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MicButton extends StatefulWidget {
  const _MicButton({required this.listening, required this.onTap});

  final bool listening;
  final VoidCallback onTap;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 58,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              if (widget.listening) ...[
                for (final offset in [0.0, 0.5])
                  Builder(builder: (context) {
                    final progress = (t + offset) % 1.0;
                    return Container(
                      width: 58 + progress * 34,
                      height: 58 + progress * 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: EmoColors.blue
                              .withValues(alpha: (1 - progress) * 0.5),
                          width: 1.5,
                        ),
                      ),
                    );
                  }),
              ],
              child!,
            ],
          );
        },
        child: Pressable(
          onTap: widget.onTap,
          scale: 0.94,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: widget.listening
                  ? const LinearGradient(
                      colors: [Color(0xFF7FB6FF), Color(0xFF2E7DFF)],
                    )
                  : EmoGradients.primary,
              border: Border.all(color: Colors.white.withValues(alpha: 0.45)),
              boxShadow: [
                BoxShadow(
                  color: EmoColors.blue.withValues(alpha: 0.38),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Icon(
              widget.listening ? Icons.stop_rounded : Icons.mic_rounded,
              color: Colors.white,
              size: 25,
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.active,
    required this.loading,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool active;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 106,
      child: GlassSurface(
        radius: 22,
        padding: const EdgeInsets.fromLTRB(10, 11, 10, 11),
        onTap: loading ? null : onTap,
        gradient: active
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xF2FFFFFF), Color(0xE3EAF5FF)],
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconBadge(
                  icon: icon,
                  active: active,
                  size: 32,
                  radius: 11,
                ),
                const Spacer(),
                if (loading)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.8,
                      valueColor: AlwaysStoppedAnimation(EmoColors.blue),
                    ),
                  )
                else
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active
                          ? EmoColors.blue
                          : EmoColors.ink.withValues(alpha: 0.12),
                    ),
                  ),
              ],
            ),
            const Spacer(),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: EmoColors.ink,
                ),
              ),
            ),
            const SizedBox(height: 1),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: active ? EmoColors.blue : EmoColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextRoutineCard extends StatelessWidget {
  const _NextRoutineCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final routine = state.nextRoutine;
    if (routine == null) {
      return GlassSurface(
        padding: const EdgeInsets.all(16),
        onTap: () => state.setTab(1),
        child: Row(
          children: [
            const IconBadge(icon: Icons.bolt_rounded, size: 44),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No routines scheduled',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    'Create one to make Emo work on its own.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: EmoColors.faint, size: 22),
          ],
        ),
      );
    }

    return GlassSurface(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconBadge(icon: emoIcon(routine.iconKey), size: 44, active: true),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT UP · ${routine.time}',
                  style: emoLabel(size: 9.5),
                ),
                const SizedBox(height: 3),
                Text(
                  routine.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 1),
                Text(
                  routine.actionSummary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Pressable(
            onTap: state.runningRoutines.contains(routine.id)
                ? null
                : () async {
                    final summary = await state.runRoutine(routine);
                    if (context.mounted) {
                      emoSnack(
                        context,
                        summary.isEmpty ? 'Nothing to run' : summary,
                        icon: Icons.bolt_rounded,
                        color: EmoColors.blue,
                      );
                    }
                  },
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: EmoGradients.glassDeep,
                border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
              ),
              child: state.runningRoutines.contains(routine.id)
                  ? const Padding(
                      padding: EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(EmoColors.blue),
                      ),
                    )
                  : const Icon(Icons.play_arrow_rounded,
                      color: EmoColors.blue, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final missing = <String>[];
    if (!state.device.accessibility) missing.add('accessibility');
    if (!state.device.notificationAccess) missing.add('notifications');
    if (!state.device.dndAccess) missing.add('Do Not Disturb');

    return GlassSurface(
      padding: const EdgeInsets.all(16),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xF5FFFFFF), Color(0xEEFFF6E8)],
      ),
      onTap: () => state.setTab(3),
      child: Row(
        children: [
          const IconBadge(
            icon: Icons.shield_outlined,
            size: 44,
            color: EmoColors.warning,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Finish setting up Emo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  '${missing.length} access${missing.length == 1 ? '' : 'es'} still needed: ${missing.join(', ')}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: EmoColors.faint, size: 22),
        ],
      ),
    );
  }
}

class VoiceBars extends StatefulWidget {
  const VoiceBars({super.key, this.color = EmoColors.blue, this.bars = 5});

  final Color color;
  final int bars;

  @override
  State<VoiceBars> createState() => _VoiceBarsState();
}

class _VoiceBarsState extends State<VoiceBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(widget.bars, (i) {
            final wave = 0.5 + 0.5 * math.sin(_controller.value * math.pi * 2 + i * 1.1);
            return Container(
              width: 3,
              height: 8 + wave * 16,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(100),
              ),
            );
          }),
        );
      },
    );
  }
}
