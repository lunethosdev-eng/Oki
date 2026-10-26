import 'package:flutter/material.dart';
import 'package:pokke/screens/profile_screen.dart';
import 'package:pokke/screens/settings_screen.dart';

/// Right-side panel on TV (not full-screen route).
Future<void> showTvSidePanel(
  BuildContext context, {
  required Widget child,
  double widthFactor = 0.38,
}) {
  return showGeneralDialog(
    context: context,
    barrierLabel: 'panel',
    barrierDismissible: true,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 320),
    pageBuilder: (ctx, anim, sec) {
      final w = MediaQuery.sizeOf(ctx).width * widthFactor;
      return Align(
        alignment: Alignment.centerRight,
        child: Material(
          color: const Color(0xFF121212),
          elevation: 12,
          child: SizedBox(
            width: w.clamp(360.0, 520.0),
            height: double.infinity,
            child: child,
          ),
        ),
      );
    },
    transitionBuilder: (ctx, anim, sec, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      );
    },
  );
}

Future<void> openTvSettings(BuildContext context) {
  return showTvSidePanel(context, child: const SettingsScreen());
}

Future<void> openTvProfile(BuildContext context) {
  return showTvSidePanel(context, child: const ProfileScreen());
}
