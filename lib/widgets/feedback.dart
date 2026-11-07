import 'package:flutter/material.dart';

import '../theme.dart';
import 'glass.dart';

void emoSnack(
  BuildContext context,
  String message, {
  IconData icon = Icons.check_circle_outline_rounded,
  Color color = EmoColors.blue,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      duration: const Duration(seconds: 3),
      content: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<T?> showEmoSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: const Color(0x66081B3D),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: builder(context),
    ),
  );
}

class SheetShell extends StatelessWidget {
  const SheetShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(22, 12, 22, 24),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: GlassSurface(
        radius: 30,
        blur: 24,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFAFFFFFF), Color(0xF2F3F9FF)],
        ),
        padding: padding,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4.5,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: EmoColors.ink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(100),
                ),
              ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
