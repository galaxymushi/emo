import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';

class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key, this.child, this.tone = 0});

  final Widget? child;
  final int tone;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 22),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFFFFFFF), Color(0xFFF5FAFF), Color(0xFFE8F3FF)],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Positioned(
              top: -160 + t * 18,
              right: -130 + t * 24,
              child: _Glow(
                size: 420,
                color: EmoColors.sky.withValues(alpha: 0.30),
              ),
            ),
            Positioned(
              top: 210 - t * 24,
              left: -190 + t * 12,
              child: _Glow(
                size: 400,
                color: EmoColors.blue.withValues(alpha: 0.16),
              ),
            ),
            Positioned(
              bottom: -180 + t * 20,
              left: 40,
              child: _Glow(
                size: 460,
                color: const Color(0xFF8CC8FF).withValues(alpha: 0.22),
              ),
            ),
            Positioned(
              top: MediaQuery.sizeOf(context).height * 0.32,
              right: -80,
              child: _Glow(
                size: 260,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
            if (widget.child != null) widget.child!,
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0.0, 1.0],
          ),
        ),
      ),
    );
  }
}

class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.lightImpact();
              widget.onTap!();
            },
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp: widget.onTap == null ? null : (_) => setState(() => _down = false),
      onTapCancel: widget.onTap == null ? null : () => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: const Duration(milliseconds: 130),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.padding,
    this.radius = EmoSizes.cardRadius,
    this.blur = 16,
    this.gradient,
    this.borderColor,
    this.shadow = true,
    this.onTap,
    this.width,
    this.height,
    this.alignment,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final double blur;
  final Gradient? gradient;
  final Color? borderColor;
  final bool shadow;
  final VoidCallback? onTap;
  final double? width;
  final double? height;
  final Alignment? alignment;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    Widget content = Container(
      width: width,
      height: height,
      alignment: alignment,
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient ?? EmoGradients.glass,
        borderRadius: borderRadius,
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      child: child,
    );

    content = ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: content,
      ),
    );

    if (onTap != null) {
      content = Pressable(onTap: onTap, scale: 0.985, child: content);
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow ? EmoShadows.card : null,
      ),
      child: content,
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.active = false,
    this.size = 44,
    this.radius = 15,
    this.color,
  });

  final IconData icon;
  final bool active;
  final double size;
  final double radius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: active
            ? EmoGradients.primary
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.95),
                  EmoColors.ice.withValues(alpha: 0.9),
                ],
              ),
        border: Border.all(
          color: active
              ? Colors.white.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.9),
        ),
        boxShadow: active
            ? EmoShadows.button
            : [
                BoxShadow(
                  color: const Color(0xFF2E7DFF).withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Icon(
        icon,
        size: size * 0.46,
        color: color ?? (active ? Colors.white : EmoColors.blue),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.loading = false,
    this.height = 56,
    this.expand = true,
    this.enabled = true,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool loading;
  final double height;
  final bool expand;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !loading && onTap != null;
    final child = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 26),
      decoration: BoxDecoration(
        gradient: active ? EmoGradients.primary : EmoGradients.primarySoft,
        borderRadius: BorderRadius.circular(EmoSizes.pill),
        boxShadow: active ? EmoShadows.button : null,
        border: Border.all(
          color: Colors.white.withValues(alpha: active ? 0.28 : 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            )
          else if (icon != null)
            Icon(
              icon,
              size: 19,
              color: active ? Colors.white : EmoColors.blueInk,
            ),
          if (loading || icon != null) const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.1,
              color: active ? Colors.white : EmoColors.blueInk,
            ),
          ),
        ],
      ),
    );

    return Pressable(
      onTap: active ? onTap : null,
      scale: 0.975,
      child: expand ? SizedBox(width: double.infinity, child: child) : child,
    );
  }
}

class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.height = 48,
    this.expand = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(EmoSizes.pill),
        gradient: EmoGradients.glassDeep,
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
      ),
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: EmoColors.blue),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: EmoColors.blueInk,
            ),
          ),
        ],
      ),
    );
    return Pressable(
      onTap: onTap,
      child: expand ? SizedBox(width: double.infinity, child: child) : child,
    );
  }
}

class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 44,
    this.iconSize = 20,
    this.dark = false,
    this.badge,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final bool dark;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: dark ? EmoGradients.primary : EmoGradients.glassDeep,
          border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
          boxShadow: dark
              ? EmoShadows.button
              : [
                  BoxShadow(
                    color: const Color(0xFF2E7DFF).withValues(alpha: 0.08),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: iconSize, color: dark ? Colors.white : EmoColors.ink),
            if (badge != null)
              Positioned(top: 9, right: 9, child: badge!),
          ],
        ),
      ),
    );
  }
}

class EmoSwitch extends StatelessWidget {
  const EmoSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.width = 50,
    this.height = 30,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      scale: 0.92,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: width,
        height: height,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height),
          gradient: value ? EmoGradients.primary : null,
          color: value ? null : const Color(0xFFDCE5F2).withValues(alpha: 0.9),
          border: Border.all(
            color: value
                ? Colors.white.withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.7),
          ),
          boxShadow: value
              ? [
                  BoxShadow(
                    color: EmoColors.blue.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: height - 6,
            height: height - 6,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A1B3D).withValues(alpha: 0.16),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.label,
    this.color = EmoColors.blue,
    this.icon,
    this.compact = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3.5 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: compact ? 11 : 12, color: color)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          if (icon != null || label.isNotEmpty) const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: compact ? 10.5 : 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.trailing,
    this.padding = const EdgeInsets.only(bottom: 12),
  });

  final String title;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: EmoColors.ink,
            ),
          ),
          const Spacer(),
          ?trailing,
        ],
      ),
    );
  }
}

class LoadingDots extends StatefulWidget {
  const LoadingDots({super.key, this.color = EmoColors.blue, this.size = 5});

  final Color color;
  final double size;

  @override
  State<LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<LoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
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
          children: List.generate(3, (i) {
            final phase = (_controller.value + i * 0.18) % 1.0;
            final lift = math.sin(phase * math.pi * 2).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Transform.translate(
                offset: Offset(0, -3 * lift),
                child: Opacity(
                  opacity: 0.35 + lift * 0.65,
                  child: Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      color: widget.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(EmoSizes.page, 8, EmoSizes.page, 18),
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 12), trailing!],
        ],
      ),
    );
  }
}

class EmoLoadingBar extends StatelessWidget {
  const EmoLoadingBar({super.key, required this.value, this.height = 4});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Container(
            height: height,
            color: EmoColors.blue.withValues(alpha: 0.10),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Container(
                  width: constraints.maxWidth * v,
                  height: height,
                  decoration: BoxDecoration(
                    gradient: EmoGradients.primary,
                    borderRadius: BorderRadius.circular(height),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
