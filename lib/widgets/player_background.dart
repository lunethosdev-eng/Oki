import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';

/// Player backdrop modes:
/// color | blur | cinematic | dark | gradient | mesh
class PlayerBackground extends StatefulWidget {
  final String? coverUrl;
  final String? animatedCoverUrl;
  final String mode;
  final bool tv;
  const PlayerBackground({
    super.key,
    this.coverUrl,
    this.animatedCoverUrl,
    required this.mode,
    this.tv = false,
  });

  @override
  State<PlayerBackground> createState() => _PlayerBackgroundState();
}

class _PlayerBackgroundState extends State<PlayerBackground>
    with SingleTickerProviderStateMixin {
  Color _a = const Color(0xFF1A1A2E);
  Color _b = const Color(0xFF16213E);
  Color _c = const Color(0xFF0F3460);
  late final AnimationController _drift;

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _extract();
  }

  @override
  void didUpdateWidget(covariant PlayerBackground old) {
    super.didUpdateWidget(old);
    if (old.coverUrl != widget.coverUrl) _extract();
  }

  @override
  void dispose() {
    _drift.dispose();
    super.dispose();
  }

  Future<void> _extract() async {
    final url = widget.coverUrl;
    if (url == null || !url.startsWith('http')) return;
    try {
      final gen = await PaletteGenerator.fromImageProvider(
        NetworkImage(url),
        maximumColorCount: 8,
        size: const Size(80, 80),
      );
      if (!mounted) return;
      setState(() {
        _a = gen.dominantColor?.color ??
            gen.vibrantColor?.color ??
            _a;
        _b = gen.darkMutedColor?.color ??
            gen.mutedColor?.color ??
            _b;
        _c = gen.vibrantColor?.color ??
            gen.lightVibrantColor?.color ??
            _c;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final cover = widget.coverUrl;
    final hasCover = cover != null && cover.startsWith('http');

    switch (mode) {
      case 'blur':
        return Stack(
          fit: StackFit.expand,
          children: [
            if (hasCover)
              ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: Image.network(cover!, fit: BoxFit.cover),
              )
            else
              ColoredBox(color: _a),
            Container(color: Colors.black.withOpacity(widget.tv ? 0.45 : 0.35)),
          ],
        );

      case 'cinematic':
        return AnimatedBuilder(
          animation: _drift,
          builder: (_, __) {
            final t = _drift.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                if (hasCover)
                  Transform.scale(
                    scale: 1.08 + 0.04 * t,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Image.network(cover!, fit: BoxFit.cover),
                    ),
                  )
                else
                  ColoredBox(color: _b),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.2 + 0.3 * t, -0.3),
                      radius: 1.2,
                      colors: [
                        _c.withOpacity(0.35),
                        Colors.black.withOpacity(0.75),
                        Colors.black,
                      ],
                      stops: const [0.0, 0.55, 1.0],
                    ),
                  ),
                ),
                // letterbox bars feel
                Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    height: widget.tv ? 48 : 28,
                    color: Colors.black.withOpacity(0.35),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: widget.tv ? 64 : 40,
                    color: Colors.black.withOpacity(0.4),
                  ),
                ),
              ],
            );
          },
        );

      case 'dark':
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            if (hasCover)
              Opacity(
                opacity: 0.22,
                child: ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                  child: Image.network(cover!, fit: BoxFit.cover),
                ),
              ),
          ],
        );

      case 'gradient':
        return AnimatedBuilder(
          animation: _drift,
          builder: (_, __) {
            final t = _drift.value;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1 + t, -1),
                  end: Alignment(1 - t, 1),
                  colors: [
                    _a,
                    _b,
                    _c.withOpacity(0.9),
                    Colors.black,
                  ],
                  stops: const [0.0, 0.35, 0.7, 1.0],
                ),
              ),
            );
          },
        );

      case 'mesh':
        return AnimatedBuilder(
          animation: _drift,
          builder: (_, __) {
            final t = _drift.value;
            return Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(color: const Color(0xFF0B0B0F)),
                Positioned(
                  left: -80 + 40 * t,
                  top: -60,
                  child: _blob(_a.withOpacity(0.55), 280),
                ),
                Positioned(
                  right: -60 - 30 * t,
                  top: 120,
                  child: _blob(_c.withOpacity(0.45), 240),
                ),
                Positioned(
                  left: 40,
                  bottom: -40 + 20 * t,
                  child: _blob(_b.withOpacity(0.5), 260),
                ),
                if (hasCover)
                  Opacity(
                    opacity: 0.15,
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                      child: Image.network(cover!, fit: BoxFit.cover),
                    ),
                  ),
                Container(color: Colors.black.withOpacity(0.25)),
              ],
            );
          },
        );

      case 'color':
      default:
        return Stack(
          fit: StackFit.expand,
          children: [
            if (hasCover)
              Opacity(
                opacity: widget.tv ? 0.35 : 0.4,
                child: Image.network(cover!, fit: BoxFit.cover),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _a.withOpacity(0.9),
                    _b.withOpacity(0.85),
                    Colors.black.withOpacity(0.92),
                  ],
                ),
              ),
            ),
          ],
        );
    }
  }

  Widget _blob(Color color, double size) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
        ),
      ),
    );
  }
}
