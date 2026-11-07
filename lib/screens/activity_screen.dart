import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/emo_icons.dart';
import '../widgets/glass.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key, required this.state});

  final AppState state;

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  String _filter = 'all';

  AppState get state => widget.state;

  bool _matches(ActivityEvent event) {
    switch (_filter) {
      case 'done':
        return event.status == ActivityStatus.success;
      case 'failed':
        return event.status == ActivityStatus.failed;
      default:
        return true;
    }
  }

  String _groupLabel(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final diff = today.difference(day).inDays;
    if (diff <= 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return 'Earlier this week';
    return 'Earlier';
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...state.activity]..sort((a, b) => b.time.compareTo(a.time));
    final visible = sorted.where(_matches).toList();
    final groups = <String, List<ActivityEvent>>{};
    for (final event in visible) {
      groups.putIfAbsent(_groupLabel(event.time), () => []).add(event);
    }
    final doneCount =
        sorted.where((e) => e.status == ActivityStatus.success).length;
    final failedCount =
        sorted.where((e) => e.status == ActivityStatus.failed).length;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        color: EmoColors.blue,
        backgroundColor: Colors.white,
        onRefresh: state.handleResume,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
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
                title: 'Activity',
                subtitle: 'A clear record of what Emo did',
                padding: const EdgeInsets.only(bottom: 18),
                leading: const IconBadge(
                  icon: Icons.history_rounded,
                  active: true,
                  size: 44,
                ),
                trailing: GlassIconButton(
                  icon: Icons.refresh_rounded,
                  size: 44,
                  onTap: state.handleResume,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: _FilterPill(
                      label: 'All',
                      count: sorted.length,
                      selected: _filter == 'all',
                      onTap: () => setState(() => _filter = 'all'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterPill(
                      label: 'Done',
                      count: doneCount,
                      selected: _filter == 'done',
                      onTap: () => setState(() => _filter = 'done'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _FilterPill(
                      label: 'Failed',
                      count: failedCount,
                      selected: _filter == 'failed',
                      onTap: () => setState(() => _filter = 'failed'),
                    ),
                  ),
                ],
              ),
              if (state.busy) ...[
                const SizedBox(height: 16),
                _LiveCard(state: state),
              ],
              const SizedBox(height: 22),
              if (visible.isEmpty)
                _EmptyCard(filter: _filter)
              else
                for (final entry in groups.entries) ...[
                  SectionTitle(
                    title: entry.key,
                    trailing: Text(
                      '${entry.value.length}',
                      style: emoLabel(size: 10),
                    ),
                  ),
                  for (var i = 0; i < entry.value.length; i++)
                    _TimelineRow(
                      event: entry.value[i],
                      last: i == entry.value.length - 1,
                    ),
                  const SizedBox(height: 10),
                ],
              const SizedBox(height: 8),
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
                      'Emo keeps the last 90 actions on this phone. You can clear them any time in Settings.',
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
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(EmoSizes.pill),
          gradient: selected ? EmoGradients.primary : null,
          color: selected ? null : Colors.white.withValues(alpha: 0.6),
          border: Border.all(
            color: Colors.white.withValues(alpha: selected ? 0.35 : 0.9),
          ),
          boxShadow: selected ? EmoShadows.button : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : EmoColors.inkSoft,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: selected
                    ? Colors.white.withValues(alpha: 0.22)
                    : EmoColors.ink.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: selected ? Colors.white : EmoColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveCard extends StatelessWidget {
  const _LiveCard({required this.state});

  final AppState state;

  String get _lastCommand {
    for (var i = state.messages.length - 1; i >= 0; i--) {
      final message = state.messages[i];
      if (message.fromUser) return message.text;
    }
    return 'your request';
  }

  String get _runningStep {
    for (var i = state.messages.length - 1; i >= 0; i--) {
      final message = state.messages[i];
      if (message.fromUser) continue;
      for (final step in message.steps) {
        if (step.status == ExecStatus.running) return step.label;
      }
      if (message.steps.isNotEmpty) return message.steps.last.label;
      break;
    }
    return 'Preparing the next step';
  }

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 22,
      padding: const EdgeInsets.fromLTRB(15, 14, 16, 14),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFFFFFF), Color(0xFFEAF4FF)],
      ),
      borderColor: EmoColors.blue.withValues(alpha: 0.28),
      child: Row(
        children: [
          const IconBadge(
            icon: Icons.auto_awesome_rounded,
            active: true,
            size: 42,
            radius: 14,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const StatusChip(
                      label: 'Running now',
                      color: EmoColors.blue,
                      compact: true,
                    ),
                    const SizedBox(width: 7),
                    Flexible(
                      child: Text(
                        '“$_lastCommand”',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: EmoColors.muted,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _runningStep,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: EmoColors.ink,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const LoadingDots(),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.last});

  final ActivityEvent event;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = activityColor(event.status);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: EmoColors.ink.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: last ? 0 : 10),
              child: GlassSurface(
                radius: 20,
                padding: const EdgeInsets.fromLTRB(13, 12, 14, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(13),
                        color: color.withValues(alpha: 0.09),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                      child: Icon(
                        emoIcon(event.icon),
                        size: 18,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            event.title,
                            style: const TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: EmoColors.ink,
                              height: 1.3,
                            ),
                          ),
                          if (event.detail.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              event.detail,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: EmoColors.muted,
                                height: 1.4,
                              ),
                            ),
                          ],
                          const SizedBox(height: 7),
                          Row(
                            children: [
                              StatusChip(
                                label: activityLabel(event.status),
                                color: color,
                                compact: true,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  event.relativeTime,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: EmoColors.faint,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.filter});

  final String filter;

  String get _title {
    switch (filter) {
      case 'done':
        return 'Nothing completed yet';
      case 'failed':
        return 'No failed actions';
      default:
        return 'No activity yet';
    }
  }

  String get _body {
    switch (filter) {
      case 'done':
        return 'Completed commands will show up here.';
      case 'failed':
        return 'That is a good sign — nothing needs your attention.';
      default:
        return 'Ask Emo to do something from Home and every step will appear here.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      child: Column(
        children: [
          const IconBadge(
            icon: Icons.history_toggle_off_rounded,
            size: 54,
            radius: 18,
          ),
          const SizedBox(height: 14),
          Text(_title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 5),
          Text(
            _body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
