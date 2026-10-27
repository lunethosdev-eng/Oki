import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:video_player/video_player.dart';

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
  VideoPlayerController? _video;
  String? _videoUrl;

  bool _isVideo(String? url) {
    if (url == null) return false;
    final u = url.toLowerCase();
    return u.endsWith('.mp4') ||
        u.endsWith('.webm') ||
        u.endsWith('.mov') ||
        u.contains('.mp4?') ||
        u.contains('video');
  }

  @override
  void initState() {
    super.initState();
    _drift = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);
    _extract();
    _syncVideo();
  }

  @override
  void didUpdateWidget(covariant PlayerBackground old) {
    super.didUpdateWidget(old);
    if (old.coverUrl != widget.coverUrl) _extract();
    if (old.animatedCoverUrl != widget.animatedCoverUrl ||
        old.coverUrl != widget.coverUrl) {
      _syncVideo();
    }
  }

  Future<void> _syncVideo() async {
    final anim = widget.animatedCoverUrl;
    final cover = widget.coverUrl;
    final target = _isVideo(anim)
        ? anim
        : (_isVideo(cover) ? cover : null);
    if (target == _videoUrl) return;
    await _video?.dispose();
    _video = null;
    _videoUrl = target;
    if (target == null) {
      if (mounted) setState(() {});
      return;
    }
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(target));
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      await c.play();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _video = c);
    } catch (e) {
      debugPrint('animated cover video: $e');
      _video = null;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _drift.dispose();
    _video?.dispose();
    super.dispose();
  }

  Future<void> _extract() async {
    final url = widget.coverUrl;
    if (url == null || !url.startsWith('http') || _isVideo(url)) return;
    try {
      final gen = await PaletteGenerator.fromImageProvider(
        NetworkImage(url),
        maximumColorCount: 8,
        size: const Size(80, 80),
      );
      if (!mounted) return;
      setState(() {
        _a = gen.dominantColor?.color ?? gen.vibrantColor?.color ?? _a;
        _b = gen.darkMutedColor?.color ?? gen.mutedColor?.color ?? _b;
        _c = gen.vibrantColor?.color ?? gen.lightVibrantColor?.color ?? _c;
      });
    } catch (_) {}
  }

  Widget _videoLayer({double opacity = 1}) {
    final v = _video;
    if (v == null || !v.value.isInitialized) {
      return const SizedBox.shrink();
    }
    return Opacity(
      opacity: opacity,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: v.value.size.width,
          height: v.value.size.height,
          child: VideoPlayer(v),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final cover = widget.coverUrl;
    final hasCover = cover != null && cover.startsWith('http') && !_isVideo(cover);
    final hasVideo = _video != null && _video!.value.isInitialized;

    // Prefer looping MP4 as full backdrop when available
    if (hasVideo && (mode == 'color' || mode == 'blur' || mode == 'cinematic')) {
      return Stack(
        fit: StackFit.expand,
        children: [
          _videoLayer(),
          if (mode == 'blur')
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(color: Colors.black.withOpacity(0.25)),
            )
          else
            Container(color: Colors.black.withOpacity(widget.tv ? 0.35 : 0.25)),
        ],
      );
    }

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
                if (hasVideo)
                  _videoLayer()
                else if (hasCover)
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
              ],
            );
          },
        );

      case 'dark':
        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            if (hasVideo)
              _videoLayer(opacity: 0.22)
            else if (hasCover)
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
                const ColoredBox(color: Color(0xFF0B0B0F)),
                Positioned(
                  left: -80 + 40 * t,
                  top: -40,
                  child: _blob(_a.withOpacity(0.55), 220),
                ),
                Positioned(
                  right: -60 - 20 * t,
                  bottom: 80,
                  child: _blob(_c.withOpacity(0.4), 260),
                ),
                Positioned(
                  left: 40,
                  bottom: -30 + 20 * t,
                  child: _blob(_b.withOpacity(0.5), 180),
                ),
                if (hasVideo) _videoLayer(opacity: 0.35),
              ],
            );
          },
        );

      case 'color':
      default:
        return Stack(
          fit: StackFit.expand,
          children: [
            if (hasVideo)
              _videoLayer()
            else if (hasCover)
              Image.network(cover!, fit: BoxFit.cover)
            else
              ColoredBox(color: _a),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.55),
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
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
