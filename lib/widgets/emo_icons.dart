import 'package:flutter/material.dart';

import '../app_state.dart';
import '../models.dart';
import '../theme.dart';
import 'feedback.dart';
import 'glass.dart';

Route<T> emoRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    transitionDuration: const Duration(milliseconds: 330),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.035),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

IconData emoIcon(String key) {
  switch (key) {
    case 'torch':
      return Icons.flashlight_on_rounded;
    case 'wifi':
      return Icons.wifi_rounded;
    case 'bluetooth':
      return Icons.bluetooth_rounded;
    case 'moon':
      return Icons.dark_mode_rounded;
    case 'brightness':
      return Icons.brightness_6_rounded;
    case 'volume':
      return Icons.volume_up_rounded;
    case 'apps':
      return Icons.apps_rounded;
    case 'phone':
      return Icons.phone_in_talk_rounded;
    case 'message':
      return Icons.chat_bubble_outline_rounded;
    case 'settings':
      return Icons.settings_rounded;
    case 'battery':
      return Icons.battery_5_bar_rounded;
    case 'bell':
      return Icons.notifications_none_rounded;
    case 'back':
      return Icons.arrow_back_rounded;
    case 'home':
      return Icons.home_rounded;
    case 'recents':
      return Icons.layers_outlined;
    case 'quick':
      return Icons.tune_rounded;
    case 'lock':
      return Icons.lock_outline_rounded;
    case 'screenshot':
      return Icons.screenshot_monitor_rounded;
    case 'swipe':
      return Icons.swap_vert_rounded;
    case 'search':
      return Icons.search_rounded;
    case 'focus':
      return Icons.center_focus_strong_rounded;
    case 'movie':
      return Icons.movie_filter_rounded;
    case 'workout':
      return Icons.fitness_center_rounded;
    case 'sun':
      return Icons.wb_sunny_rounded;
    case 'help':
      return Icons.help_outline_rounded;
    case 'cloud':
      return Icons.cloud_outlined;
    case 'sparkle':
    default:
      return Icons.auto_awesome_rounded;
  }
}

Color activityColor(ActivityStatus status) {
  switch (status) {
    case ActivityStatus.success:
      return EmoColors.success;
    case ActivityStatus.failed:
      return EmoColors.danger;
    case ActivityStatus.running:
      return EmoColors.blue;
    case ActivityStatus.info:
      return EmoColors.warning;
  }
}

IconData activityIcon(ActivityStatus status) {
  switch (status) {
    case ActivityStatus.success:
      return Icons.check_rounded;
    case ActivityStatus.failed:
      return Icons.close_rounded;
    case ActivityStatus.running:
      return Icons.more_horiz_rounded;
    case ActivityStatus.info:
      return Icons.info_outline_rounded;
  }
}

String activityLabel(ActivityStatus status) {
  switch (status) {
    case ActivityStatus.success:
      return 'Done';
    case ActivityStatus.failed:
      return 'Failed';
    case ActivityStatus.running:
      return 'Running';
    case ActivityStatus.info:
      return 'Needs you';
  }
}

void showPermissionSheet(BuildContext context, AppState state, String need) {
  showEmoSheet(
    context,
    builder: (context) => _PermissionSheet(state: state, need: need),
  );
}


class _PermissionSheet extends StatelessWidget {
  const _PermissionSheet({required this.state, required this.need});

  final AppState state;
  final String need;

  String get _title {
    switch (need) {
      case 'policy':
        return 'Allow Do Not Disturb access';
      case 'accessibility':
        return 'Turn on Emo accessibility';
      case 'notification_access':
        return 'Allow notification access';
      case 'write_settings':
        return 'Allow system settings access';
      case 'camera':
        return 'Allow camera access';
      case 'contacts':
        return 'Allow contact access';
      case 'microphone':
        return 'Allow microphone access';
      case 'bluetooth':
        return 'Allow Bluetooth access';
      default:
        return 'One more step';
    }
  }

  String get _body {
    switch (need) {
      case 'policy':
        return 'Android only lets apps change Do Not Disturb with this access. Emo uses it only when you ask.';
      case 'accessibility':
        return 'This lets Emo go back, go home and scroll for you. Emo does not read your screen.';
      case 'notification_access':
        return 'Emo can read waiting notifications and clear them when you ask.';
      case 'write_settings':
        return 'Lets brightness changes apply across the whole phone, not only inside Emo.';
      case 'camera':
        return 'The camera permission is required to switch the flashlight on and off.';
      case 'contacts':
        return 'Emo matches names you say to your contacts. Nothing leaves your phone.';
      case 'microphone':
        return 'Emo listens only while you are holding the mic.';
      case 'bluetooth':
        return 'Android needs this to read and change Bluetooth state.';
      default:
        return 'Grant access to continue.';
    }
  }

  bool get _opensSettings =>
      !['camera', 'contacts', 'microphone', 'notifications', 'bluetooth']
          .contains(need);

  @override
  Widget build(BuildContext context) {
    return SheetShell(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(icon: Icons.lock_outline_rounded, active: true, size: 50),
          const SizedBox(height: 16),
          Text(_title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            _body,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: 20),
          PrimaryButton(
            label: _opensSettings ? 'Open settings' : 'Allow',
            icon: _opensSettings ? Icons.open_in_new_rounded : Icons.check_rounded,
            onTap: () async {
              await state.grantAccess(need);
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Not now',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: EmoColors.muted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
