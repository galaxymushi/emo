import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/emo_icons.dart';
import '../widgets/feedback.dart';
import '../widgets/glass.dart';

class AutomationsScreen extends StatelessWidget {
  const AutomationsScreen({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final routines = state.routines;
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
              title: 'Automations',
              subtitle:
                  '${state.activeRoutines} active · ${routines.length} routines',
              padding: const EdgeInsets.only(bottom: 18),
              leading: const IconBadge(
                icon: Icons.bolt_rounded,
                active: true,
                size: 44,
              ),
              trailing: GlassIconButton(
                icon: Icons.add_rounded,
                size: 44,
                onTap: () => _openSheet(context, null),
              ),
            ),
            PrimaryButton(
              label: 'Create routine',
              icon: Icons.add_rounded,
              onTap: () => _openSheet(context, null),
            ),
            const SizedBox(height: 14),
            if (state.nextRoutine != null)
              GlassSurface(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const IconBadge(
                      icon: Icons.schedule_rounded,
                      size: 40,
                      radius: 13,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('NEXT RUN', style: emoLabel(size: 9)),
                          const SizedBox(height: 3),
                          Text(
                            state.nextRoutineLabel,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: EmoColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                    StatusChip(
                      label: state.nextRoutine!.time,
                      color: EmoColors.blue,
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 22),
            SectionTitle(
              title: 'Your routines',
              trailing: Text(
                routines.isEmpty ? 'None yet' : '${routines.length}',
                style: emoLabel(size: 10),
              ),
            ),
            if (routines.isEmpty)
              GlassSurface(
                padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 22),
                child: Column(
                  children: [
                    const IconBadge(
                      icon: Icons.schedule_rounded,
                      size: 52,
                      radius: 18,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'No routines yet',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Automate your evening, focus time or the drive home.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              )
            else
              for (final routine in routines) ...[
                _RoutineCard(state: state, routine: routine),
                const SizedBox(height: 11),
              ],
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 14,
                  color: EmoColors.faint,
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    'Daily routines run even when Emo is closed. Some actions need access — Emo tells you when they do.',
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
    );
  }

  void _openSheet(BuildContext context, Routine? routine) {
    showEmoSheet(
      context,
      builder: (context) => RoutineSheet(state: state, routine: routine),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.state, required this.routine});

  final AppState state;
  final Routine routine;

  @override
  Widget build(BuildContext context) {
    final running = state.runningRoutines.contains(routine.id);
    return GlassSurface(
      padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
      onTap: () => showEmoSheet(
        context,
        builder: (context) => RoutineSheet(state: state, routine: routine),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconBadge(
                icon: emoIcon(routine.iconKey),
                active: routine.enabled,
                size: 44,
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            routine.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontSize: 15),
                          ),
                        ),
                        if (!routine.enabled) ...[
                          const SizedBox(width: 7),
                          const StatusChip(
                            label: 'Paused',
                            color: EmoColors.faint,
                            compact: true,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          routine.isManual
                              ? Icons.touch_app_outlined
                              : Icons.schedule_rounded,
                          size: 12,
                          color: EmoColors.muted,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          routine.triggerLabel,
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: EmoColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              EmoSwitch(
                value: routine.enabled,
                onChanged: (value) => state.toggleRoutine(routine, value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(11, 9, 9, 9),
            decoration: BoxDecoration(
              color: EmoColors.blue.withValues(alpha: 0.055),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.75)),
            ),
            child: Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 13, color: EmoColors.blue),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    routine.actionSummary.isEmpty
                        ? 'No actions yet'
                        : routine.actionSummary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: EmoColors.inkSoft,
                    ),
                  ),
                ),
                if (routine.isManual)
                  Pressable(
                    onTap: running
                        ? null
                        : () async {
                            final summary = await state.runRoutine(routine);
                            if (context.mounted) {
                              emoSnack(
                                context,
                                summary.isEmpty ? 'Nothing to run' : summary,
                                icon: Icons.play_arrow_rounded,
                              );
                            }
                          },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        gradient: EmoGradients.primary,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: running
                          ? const SizedBox(
                              width: 11,
                              height: 11,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                                valueColor:
                                    AlwaysStoppedAnimation(Colors.white),
                              ),
                            )
                          : const Text(
                              'Run',
                              style: TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RoutineSheet extends StatefulWidget {
  const RoutineSheet({super.key, required this.state, this.routine});

  final AppState state;
  final Routine? routine;

  @override
  State<RoutineSheet> createState() => _RoutineSheetState();
}

class _RoutineSheetState extends State<RoutineSheet> {
  late final TextEditingController _name =
      TextEditingController(text: widget.routine?.name ?? '');
  late String _iconKey = widget.routine?.iconKey ?? 'sparkle';
  late bool _daily = widget.routine?.trigger != 'manual';
  late TimeOfDay _time = _parseTime(widget.routine?.time ?? '07:30');

  late bool _dnd = _hasAction('dnd');
  late bool _torch = _hasAction('torch');
  late bool _brightness = _hasAction('brightness');
  late bool _volume = _hasAction('volume');
  late double _brightnessValue = _actionValue('brightness', 0.3);
  late double _volumeValue = _actionValue('volume', 0.4);

  bool _error = false;
  bool _saving = false;

  static const _icons = ['sparkle', 'sun', 'focus', 'moon', 'movie', 'workout'];

  TimeOfDay _parseTime(String time) {
    final parts = time.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts.first) ?? 7,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 30 : 30,
    );
  }

  bool _hasAction(String type) =>
      widget.routine?.actions.any((a) => a.type == type) ?? false;

  double _actionValue(String type, double fallback) {
    for (final action in widget.routine?.actions ?? <RoutineAction>[]) {
      if (action.type == type) {
        return (action.value as num?)?.toDouble() ?? fallback;
      }
    }
    return fallback;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String get _timeString =>
      '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}';

  List<RoutineAction> _collectActions() {
    final actions = <RoutineAction>[];
    if (_dnd) {
      actions.add(const RoutineAction(
        type: 'dnd',
        label: 'Do Not Disturb on',
        value: 'none',
      ));
    }
    if (_torch) {
      actions.add(const RoutineAction(
        type: 'torch',
        label: 'Torch off',
        value: false,
      ));
    }
    if (_brightness) {
      actions.add(RoutineAction(
        type: 'brightness',
        label: 'Brightness ${(_brightnessValue * 100).round()}%',
        value: _brightnessValue,
      ));
    }
    if (_volume) {
      actions.add(RoutineAction(
        type: 'volume',
        label: 'Volume ${(_volumeValue * 100).round()}%',
        value: _volumeValue,
        stream: 'music',
      ));
    }
    return actions;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final actions = _collectActions();
    if (name.isEmpty || actions.isEmpty) {
      setState(() => _error = true);
      return;
    }
    setState(() {
      _saving = true;
      _error = false;
    });
    final routine = Routine(
      id: widget.routine?.id ??
          'routine-${DateTime.now().microsecondsSinceEpoch}',
      name: name,
      iconKey: _iconKey,
      enabled: widget.routine?.enabled ?? true,
      trigger: _daily ? 'time' : 'manual',
      time: _timeString,
      actions: actions,
    );
    await widget.state.saveRoutine(routine, isNew: widget.routine == null);
    if (!mounted) return;
    Navigator.of(context).pop();
    emoSnack(
      context,
      widget.routine == null
          ? '“$name” is ready'
          : '“$name” updated',
      icon: Icons.bolt_rounded,
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delete routine?',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '“${widget.routine?.name}” will stop running. This can’t be undone.',
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
                      'Delete',
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
    await widget.state.deleteRoutine(widget.routine!.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.routine != null;
    return SheetShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      editing ? 'Edit routine' : 'New routine',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      editing
                          ? 'Changes run from the next trigger.'
                          : 'A few actions, run automatically.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              GlassIconButton(
                icon: Icons.close_rounded,
                size: 38,
                onTap: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text('NAME', style: emoLabel(size: 9.5)),
          const SizedBox(height: 7),
          GlassSurface(
            radius: 16,
            blur: 10,
            shadow: false,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
            child: TextField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              onChanged: (_) {
                if (_error) setState(() => _error = false);
              },
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: EmoColors.ink,
              ),
              cursorColor: EmoColors.blue,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 13),
                hintText: 'e.g. Good night',
                hintStyle: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: EmoColors.faint,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text('ICON', style: emoLabel(size: 9.5)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 9,
            children: _icons.map((key) {
              final selected = key == _iconKey;
              return Pressable(
                onTap: () => setState(() => _iconKey = key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: selected ? EmoGradients.primary : null,
                    color: selected ? null : Colors.white.withValues(alpha: 0.65),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    boxShadow: selected ? EmoShadows.button : null,
                  ),
                  child: Icon(
                    emoIcon(key),
                    size: 20,
                    color: selected ? Colors.white : EmoColors.blue,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          Text('WHEN', style: emoLabel(size: 9.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SelectPill(
                  label: 'Every day',
                  icon: Icons.schedule_rounded,
                  selected: _daily,
                  onTap: () => setState(() => _daily = true),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: _SelectPill(
                  label: 'Manual only',
                  icon: Icons.touch_app_outlined,
                  selected: !_daily,
                  onTap: () => setState(() => _daily = false),
                ),
              ),
            ],
          ),
          if (_daily) ...[
            const SizedBox(height: 9),
            GlassSurface(
              radius: 16,
              blur: 10,
              shadow: false,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _time,
                  helpText: 'Routine time',
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: Theme.of(context).colorScheme.copyWith(
                            primary: EmoColors.blue,
                            surface: Colors.white,
                          ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) setState(() => _time = picked);
              },
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded,
                      size: 18, color: EmoColors.blue),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Runs every day at',
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: EmoColors.inkSoft,
                      ),
                    ),
                  ),
                  Text(
                    _timeString,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: EmoColors.blueInk,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded,
                      size: 18, color: EmoColors.faint),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Text('ACTIONS', style: emoLabel(size: 9.5)),
              const Spacer(),
              if (_error)
                Text(
                  'Pick at least one action',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: _name.text.trim().isEmpty && _collectActions().isEmpty
                        ? EmoColors.danger
                        : EmoColors.warning,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          _ActionToggle(
            icon: Icons.do_not_disturb_on_rounded,
            title: 'Do Not Disturb',
            subtitle: 'Quiet all alerts',
            value: _dnd,
            onChanged: (v) => setState(() => _dnd = v),
          ),
          const SizedBox(height: 8),
          _ActionToggle(
            icon: Icons.flashlight_off_rounded,
            title: 'Turn torch off',
            subtitle: 'Useful at night',
            value: _torch,
            onChanged: (v) => setState(() => _torch = v),
          ),
          const SizedBox(height: 8),
          _SliderAction(
            icon: Icons.brightness_6_rounded,
            title: 'Screen brightness',
            value: _brightnessValue,
            enabled: _brightness,
            onToggle: (v) => setState(() => _brightness = v),
            onChanged: (v) => setState(() => _brightnessValue = v),
          ),
          const SizedBox(height: 8),
          _SliderAction(
            icon: Icons.volume_up_rounded,
            title: 'Media volume',
            value: _volumeValue,
            enabled: _volume,
            onToggle: (v) => setState(() => _volume = v),
            onChanged: (v) => setState(() => _volumeValue = v),
          ),
          const SizedBox(height: 22),
          PrimaryButton(
            label: editing ? 'Save changes' : 'Save routine',
            icon: Icons.check_rounded,
            loading: _saving,
            onTap: _save,
          ),
          if (editing)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Center(
                child: TextButton.icon(
                  onPressed: _confirmDelete,
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 17, color: EmoColors.danger),
                  label: const Text(
                    'Delete routine',
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: EmoColors.danger,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SelectPill extends StatelessWidget {
  const _SelectPill({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: selected ? EmoGradients.primary : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.62),
          border: Border.all(
            color: selected
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.9),
          ),
          boxShadow: selected ? EmoShadows.button : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? Colors.white : EmoColors.inkSoft,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : EmoColors.inkSoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionToggle extends StatelessWidget {
  const _ActionToggle({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 16,
      blur: 10,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(13, 10, 12, 10),
      child: Row(
        children: [
          IconBadge(icon: icon, active: value, size: 34, radius: 11),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: EmoColors.ink,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: EmoColors.muted,
                  ),
                ),
              ],
            ),
          ),
          EmoSwitch(
            value: value,
            onChanged: onChanged,
            width: 44,
            height: 26,
          ),
        ],
      ),
    );
  }
}

class _SliderAction extends StatelessWidget {
  const _SliderAction({
    required this.icon,
    required this.title,
    required this.value,
    required this.enabled,
    required this.onToggle,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final double value;
  final bool enabled;
  final ValueChanged<bool> onToggle;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 16,
      blur: 10,
      shadow: false,
      padding: const EdgeInsets.fromLTRB(13, 10, 12, 4),
      child: Column(
        children: [
          Row(
            children: [
              IconBadge(icon: icon, active: enabled, size: 34, radius: 11),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: EmoColors.ink,
                  ),
                ),
              ),
              EmoSwitch(
                value: enabled,
                onChanged: onToggle,
                width: 44,
                height: 26,
              ),
            ],
          ),
          if (enabled)
            Row(
              children: [
                const SizedBox(width: 45),
                Expanded(
                  child: Slider(
                    value: value.clamp(0.05, 1.0),
                    min: 0.05,
                    max: 1,
                    onChanged: onChanged,
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text(
                    '${(value * 100).round()}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: EmoColors.muted,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
