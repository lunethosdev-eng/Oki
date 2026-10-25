import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pokke/screens/auth_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AuthScreen(),
          transitionsBuilder: (_, a, __, c) =>
              FadeTransition(opacity: a, child: c),
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo/pokke_logo.png',
              width: 120,
              height: 120,
              errorBuilder: (_, __, ___) => Icon(Icons.album,
                  size: 100, color: cs.onSurface.withOpacity(0.8)),
            )
                .animate()
                .fadeIn(duration: 600.ms)
                .scale(
                    begin: const Offset(0.88, 0.88),
                    curve: Curves.easeOutCubic),
            const SizedBox(height: 28),
            Text(
              'Pokke',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: cs.onSurface,
              ),
            ).animate().fadeIn(delay: 300.ms, duration: 500.ms),
            const SizedBox(height: 8),
            Text(
              'Music, together.',
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withOpacity(0.45),
                letterSpacing: 0.4,
              ),
            ).animate().fadeIn(delay: 550.ms, duration: 500.ms),
          ],
        ),
      ),
    );
  }
}
