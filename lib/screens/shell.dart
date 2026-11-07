import 'package:flutter/material.dart';

import '../app_state.dart';
import '../screens/activity_screen.dart';
import '../screens/automations_screen.dart';
import '../screens/home_screen.dart';
import '../screens/settings_screen.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/orb.dart';

class EmoShell extends StatelessWidget {
  const EmoShell({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        if (state.booting) {
          return const _SplashScreen();
        }
        return Scaffold(
          extendBody: true,
          backgroundColor: Colors.transparent,
          body: AmbientBackground(
            child: IndexedStack(
              index: state.tab,
              children: [
                HomeScreen(state: state),
                AutomationsScreen(state: state),
                ActivityScreen(state: state),
                SettingsScreen(state: state),
              ],
            ),
          ),
          bottomNavigationBar: _EmoNavBar(
            index: state.tab,
            onChanged: state.setTab,
          ),
        );
      },
    );
  }
}

class _EmoNavBar extends StatelessWidget {
  const _EmoNavBar({required this.index, required this.onChanged});

  final int index;
  final ValueChanged<int> onChanged;

  static const _items = [
    (Icons.space_dashboard_outlined, Icons.space_dashboard_rounded, 'Home'),
    (Icons.bolt_outlined, Icons.bolt_rounded, 'Automations'),
    (Icons.history_rounded, Icons.history_rounded, 'Activity'),
    (Icons.tune_rounded, Icons.tune_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewPaddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottom),
      child: GlassSurface(
        radius: 28,
        blur: 22,
        padding: const EdgeInsets.all(7),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xE8FFFFFF), Color(0xC9EFF6FF)],
        ),
        child: Row(
          children: List.generate(_items.length, (i) {
            final active = i == index;
            final item = _items[i];
            return Expanded(
              child: Pressable(
                scale: 0.95,
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOutCubic,
                  height: 54,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(21),
                    gradient: active ? EmoGradients.primary : null,
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: EmoColors.blue.withValues(alpha: 0.32),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                              spreadRadius: -4,
                            ),
                          ]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        active ? item.$2 : item.$1,
                        size: 21,
                        color: active ? Colors.white : EmoColors.muted,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.$3,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.1,
                          color: active ? Colors.white : EmoColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AmbientBackground(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const EmoOrb(size: 186, thinking: true),
              const SizedBox(height: 8),
              Text(
                'Emo',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      letterSpacing: -1.2,
                    ),
              ),
              const SizedBox(height: 8),
              const LoadingDots(),
            ],
          ),
        ),
      ),
    );
  }
}
