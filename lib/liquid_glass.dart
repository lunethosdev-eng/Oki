import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:pokke/services/settings_service.dart';

/// Real backdrop blur glass. Only active when Settings.liquidGlassEnabled.
class LiquidGlass extends StatelessWidget {
  final Widget child;
  final double? blur;
  final double? opacity;
  final BorderRadius borderRadius;
  final Color? tint;

  const LiquidGlass({
    super.key,
    required this.child,
    this.blur,
    this.opacity,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.tint,
  });

  @override
  Widget build(BuildContext context) {
    final s = SettingsService.instance;
    final scheme = Theme.of(context).colorScheme;

    if (!s.liquidGlassEnabled) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: ColoredBox(
          color: scheme.surfaceContainerHighest.withOpacity(0.92),
          child: child,
        ),
      );
    }

    final b = blur ?? s.liquidGlassBlur;
    final o = opacity ?? s.liquidGlassOpacity;
    Color base;
    switch (s.liquidGlassColorMode) {
      case 'custom':
        base = s.liquidGlassCustomColor;
        break;
      case 'mono':
        base = scheme.onSurface;
        break;
      case 'system':
      default:
        base = tint ?? scheme.primary;
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: b, sigmaY: b),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            color: base.withOpacity(o),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: child,
        ),
      ),
    );
  }
}
