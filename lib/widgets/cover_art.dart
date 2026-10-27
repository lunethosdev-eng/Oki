import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Square cover that plays MP4/WebM in a silent loop when the URL is video.
class CoverArt extends StatefulWidget {
  final String? url;
  final String? animatedUrl;
  final BorderRadius borderRadius;
  final BoxFit fit;
  const CoverArt({
    super.key,
    this.url,
    this.animatedUrl,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.fit = BoxFit.cover,
  });

  @override
  State<CoverArt> createState() => _CoverArtState();
}

class _CoverArtState extends State<CoverArt> {
  VideoPlayerController? _c;
  String? _active;

  bool _isVideo(String? u) {
    if (u == null) return false;
    final x = u.toLowerCase();
    return x.endsWith('.mp4') ||
        x.endsWith('.webm') ||
        x.endsWith('.mov') ||
        x.contains('.mp4?');
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant CoverArt old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.animatedUrl != widget.animatedUrl) {
      _load();
    }
  }

  Future<void> _load() async {
    final prefer = _isVideo(widget.animatedUrl)
        ? widget.animatedUrl
        : (_isVideo(widget.url) ? widget.url : null);
    if (prefer == _active) return;
    await _c?.dispose();
    _c = null;
    _active = prefer;
    if (prefer == null) {
      if (mounted) setState(() {});
      return;
    }
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(prefer));
      await c.initialize();
      await c.setLooping(true);
      await c.setVolume(0);
      await c.play();
      if (!mounted) {
        await c.dispose();
        return;
      }
      setState(() => _c = c);
    } catch (_) {
      _c = null;
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _c;
    if (v != null && v.value.isInitialized) {
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: FittedBox(
          fit: widget.fit,
          child: SizedBox(
            width: v.value.size.width,
            height: v.value.size.height,
            child: VideoPlayer(v),
          ),
        ),
      );
    }
    final img = widget.url;
    if (img != null && img.startsWith('http') && !_isVideo(img)) {
      return ClipRRect(
        borderRadius: widget.borderRadius,
        child: Image.network(img, fit: widget.fit, width: double.infinity, height: double.infinity),
      );
    }
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: Container(
        color: Colors.white12,
        child: const Icon(Icons.music_note, size: 48, color: Colors.white38),
      ),
    );
  }
}
