import 'package:flutter/material.dart';
import 'package:pokke/services/lyrics_service.dart';
import 'package:pokke/services/player_controller.dart';
import 'package:pokke/services/settings_service.dart';

class KaraokeLyrics extends StatefulWidget {
  final String title;
  final String artist;
  final bool expanded;
  final VoidCallback? onExpandToggle;
  const KaraokeLyrics({
    super.key,
    required this.title,
    required this.artist,
    this.expanded = false,
    this.onExpandToggle,
  });

  @override
  State<KaraokeLyrics> createState() => _KaraokeLyricsState();
}

class _KaraokeLyricsState extends State<KaraokeLyrics> {
  List<({double t, String line})> _lines = [];
  String? _plain;
  String? _translation;
  bool _loading = true;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    PlayerController.instance.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant KaraokeLyrics old) {
    super.didUpdateWidget(old);
    if (old.title != widget.title || old.artist != widget.artist) {
      _load();
    }
  }

  @override
  void dispose() {
    PlayerController.instance.removeListener(_onTick);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _lines = [];
      _plain = null;
      _translation = null;
    });
    final raw = await LyricsService.instance.fetch(
      title: widget.title,
      artist: widget.artist,
    );
    if (!mounted) return;
    if (raw == null) {
      setState(() {
        _loading = false;
        _plain = 'Sin letras disponibles';
      });
      return;
    }
    final parsed = LyricsService.instance.parseLrc(raw);
    setState(() {
      _loading = false;
      if (parsed.isNotEmpty) {
        _lines = parsed;
      } else {
        _plain = raw;
      }
    });
    // Translation placeholder — AI path when beta karaoke on
    if (SettingsService.instance.flag('karaoke_ai')) {
      // Real AI translation can plug Groq/OpenRouter here
      setState(() => _translation = null);
    }
  }

  void _onTick() {
    if (!mounted || _lines.isEmpty) return;
    setState(() {});
    final pos = PlayerController.instance.position.inMilliseconds / 1000.0;
    final i = _activeIndex(pos);
    if (i >= 0 && _scroll.hasClients) {
      final target = (i * (widget.expanded ? 44.0 : 36.0)) - 48;
      _scroll.animateTo(
        target.clamp(0.0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  int _activeIndex(double pos) {
    if (_lines.isEmpty) return -1;
    var idx = 0;
    for (var i = 0; i < _lines.length; i++) {
      if (_lines[i].t <= pos) idx = i;
    }
    return idx;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_loading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    if (_plain != null && _lines.isEmpty) {
      return GestureDetector(
        onTap: widget.onExpandToggle,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Text(_plain!,
              style: TextStyle(
                  color: cs.onSurface.withOpacity(0.55), height: 1.45)),
        ),
      );
    }
    final pos = PlayerController.instance.position.inMilliseconds / 1000.0;
    final active = _activeIndex(pos);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.onExpandToggle != null)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              icon: Icon(widget.expanded
                  ? Icons.fullscreen_exit
                  : Icons.fullscreen),
              onPressed: widget.onExpandToggle,
            ),
          ),
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            itemCount: _lines.length,
            itemBuilder: (_, i) {
              final on = i == active;
              final past = i < active;
              return AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                style: TextStyle(
                  fontSize: on
                      ? (widget.expanded ? 26 : 18)
                      : (widget.expanded ? 18 : 15),
                  fontWeight: on ? FontWeight.w800 : FontWeight.w500,
                  height: 1.35,
                  color: on
                      ? cs.primary
                      : past
                          ? cs.onSurface.withOpacity(0.32)
                          : cs.onSurface.withOpacity(0.55),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_lines[i].line),
                      if (_translation != null && on)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(_translation!,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: cs.onSurface.withOpacity(0.45))),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
