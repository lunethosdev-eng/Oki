import 'package:flutter/material.dart';
import 'package:characters/characters.dart';
import 'package:pokke/services/lyrics_service.dart';
import 'package:pokke/services/player_controller.dart';
import 'package:pokke/services/settings_service.dart';

/// Settings → Letras:
/// - normal: active line only (no letter color)
/// - color: smooth letter-by-letter karaoke
/// - emotion: letter color + strong words in red + ambient bg glow
class KaraokeLyrics extends StatefulWidget {
  final String title;
  final String artist;
  final bool expanded;
  final VoidCallback? onExpandToggle;
  final bool fullscreen;

  const KaraokeLyrics({
    super.key,
    required this.title,
    required this.artist,
    this.expanded = false,
    this.onExpandToggle,
    this.fullscreen = false,
  });

  @override
  State<KaraokeLyrics> createState() => _KaraokeLyricsState();
}

class _KaraokeLyricsState extends State<KaraokeLyrics>
    with TickerProviderStateMixin {
  List<({double t, String line})> _lines = [];
  String? _plain;
  bool _loading = true;
  final _scroll = ScrollController();
  int _lastActive = -1;
  late final AnimationController _glow;

  static final _strong = RegExp(
    r'\b(love|hate|cry|pain|heart|die|kill|broken|lonely|angry|sad|tears|'
    r'amor|odio|llorar|dolor|corazón|morir|roto|sola|solo|triste|lágrimas|'
    r'unhappy|hurt|bleed|scream|fear|fire|burn|no|anymore|pretty|ugly)\b',
    caseSensitive: false,
  );
  static final _soft = RegExp(
    r'\b(happy|smile|dream|hope|soft|gentle|peace|light|sky|kiss|'
    r'feliz|sonrisa|sueño|esperanza|paz|luz|cielo)\b',
    caseSensitive: false,
  );

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _load();
    PlayerController.instance.addListener(_onTick);
  }

  @override
  void didUpdateWidget(covariant KaraokeLyrics old) {
    super.didUpdateWidget(old);
    if (old.title != widget.title || old.artist != widget.artist) _load();
  }

  @override
  void dispose() {
    PlayerController.instance.removeListener(_onTick);
    _scroll.dispose();
    _glow.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _lines = [];
      _plain = null;
      _lastActive = -1;
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
  }

  int _activeIndex(double pos) {
    if (_lines.isEmpty) return -1;
    var i = 0;
    for (var k = 0; k < _lines.length; k++) {
      if (_lines[k].t <= pos) {
        i = k;
      } else {
        break;
      }
    }
    return i;
  }

  void _onTick() {
    if (!mounted || _lines.isEmpty) return;
    final pos = PlayerController.instance.position.inMilliseconds / 1000.0;
    final i = _activeIndex(pos);
    if (i != _lastActive) {
      _lastActive = i;
      setState(() {});
      _autoScroll(i);
    } else {
      // letter progress within the same line
      setState(() {});
    }
  }

  void _autoScroll(int i) {
    if (!_scroll.hasClients || i < 0) return;
    final lineH = widget.fullscreen ? 56.0 : 42.0;
    final viewH = _scroll.position.viewportDimension;
    final target = (i * lineH) - viewH * 0.38;
    _scroll.animateTo(
      target.clamp(0.0, _scroll.position.maxScrollExtent),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
    );
  }

  void _openFullscreen() {
    if (widget.fullscreen) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 450),
        reverseTransitionDuration: const Duration(milliseconds: 380),
        pageBuilder: (_, __, ___) =>
            _FullscreenLyricsPage(title: widget.title, artist: widget.artist),
        transitionsBuilder: (_, anim, __, child) {
          final curved = CurvedAnimation(
            parent: anim,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Color _emotionColor(String line) {
    if (_strong.hasMatch(line)) return const Color(0xFFFF4D6D);
    if (_soft.hasMatch(line)) return const Color(0xFF7CFFB2);
    return const Color(0xFF5AC8FA);
  }

  /// Progress 0..1 of active line based on next timestamp.
  double _lineProgress(int i, double pos) {
    if (i < 0 || i >= _lines.length) return 0;
    final start = _lines[i].t;
    final end = i + 1 < _lines.length ? _lines[i + 1].t : start + 4.0;
    final span = (end - start).clamp(0.35, 30.0);
    return ((pos - start) / span).clamp(0.0, 1.0);
  }

  Widget _activeLine(String line, String mode, double progress, ColorScheme cs) {
    final base = mode == 'emotion' ? _emotionColor(line) : const Color(0xFF5AC8FA);
    if (line.isEmpty) return const SizedBox.shrink();

    if (mode == 'normal') {
      return Text(
        line,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: base,
          fontWeight: FontWeight.w800,
          fontSize: widget.fullscreen ? 28 : 20,
          height: 1.35,
        ),
      );
    }

    if (mode == 'emotion') {
      // Word-by-word: strong emotion words go red with soft glow
      final parts = <InlineSpan>[];
      final words = line.split(RegExp(r'(\s+)'));
      final total = words.where((w) => w.trim().isNotEmpty).length;
      var seen = 0;
      final exact = progress * (total == 0 ? 1 : total);
      for (final w in words) {
        if (w.trim().isEmpty) {
          parts.add(TextSpan(text: w));
          continue;
        }
        final idx = seen;
        seen++;
        final done = idx < exact;
        final strong = _strong.hasMatch(w);
        final color = !done
            ? cs.onSurface.withOpacity(0.28)
            : (strong ? const Color(0xFFFF4D6D) : base);
        parts.add(TextSpan(
          text: w,
          style: TextStyle(
            fontSize: widget.fullscreen ? 28 : 20,
            fontWeight: FontWeight.w800,
            height: 1.35,
            color: color,
            shadows: done && strong
                ? [
                    Shadow(
                      color: const Color(0xFFFF4D6D).withOpacity(0.5),
                      blurRadius: 14,
                    ),
                  ]
                : done
                    ? [
                        Shadow(
                          color: base.withOpacity(0.4),
                          blurRadius: 10,
                        ),
                      ]
                    : null,
          ),
        ));
      }
      return Text.rich(
        TextSpan(children: parts),
        textAlign: TextAlign.center,
      );
    }

    // color mode: letter-by-letter
    final chars = line.characters.toList();
    final count = chars.length;
    final exact = progress * count;
    final activeChar = exact.floor().clamp(0, count - 1);

    return Text.rich(
      TextSpan(
        children: [
          for (var c = 0; c < count; c++)
            TextSpan(
              text: chars[c],
              style: TextStyle(
                fontSize: widget.fullscreen ? 28 : 20,
                fontWeight: FontWeight.w800,
                height: 1.35,
                color: c < exact
                    ? base
                    : cs.onSurface.withOpacity(0.28),
                shadows: c == activeChar
                    ? [
                        Shadow(
                          color: base.withOpacity(0.55),
                          blurRadius: 12,
                        ),
                      ]
                    : null,
              ),
            ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final mode = SettingsService.instance.lyricsMode;
    final pos = PlayerController.instance.position.inMilliseconds / 1000.0;
    final active = _activeIndex(pos);
    final progress = _lineProgress(active, pos);

    Color? glow;
    if (mode == 'emotion' && active >= 0 && active < _lines.length) {
      glow = _emotionColor(_lines[active].line);
    }

    Widget list;
    if (_loading) {
      list = const Center(child: CircularProgressIndicator(strokeWidth: 2));
    } else if (_plain != null) {
      list = ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            _plain!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: cs.onSurface.withOpacity(0.7),
              height: 1.55,
              fontSize: widget.fullscreen ? 20 : 15,
            ),
          ),
        ],
      );
    } else {
      list = AnimatedBuilder(
        animation: _glow,
        builder: (_, __) {
          final g = glow;
          return Container(
            decoration: g != null && mode == 'emotion'
                ? BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.15,
                      colors: [
                        g.withOpacity(0.10 + 0.08 * _glow.value),
                        Colors.transparent,
                      ],
                    ),
                  )
                : null,
            child: ListView.builder(
              controller: _scroll,
              padding: EdgeInsets.fromLTRB(
                20,
                widget.fullscreen ? 72 : 16,
                20,
                widget.fullscreen ? 100 : 24,
              ),
              itemCount: _lines.length,
              itemBuilder: (_, i) {
                final line = _lines[i].line;
                final isActive = i == active;
                final isPast = i < active;
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: isActive ? 12 : 7),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 280),
                    opacity: isActive ? 1 : (isPast ? 0.38 : 0.5),
                    child: isActive
                        ? _activeLine(line, mode, progress, cs)
                        : Text(
                            line,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: widget.fullscreen ? 18 : 15,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                              color: cs.onSurface.withOpacity(0.45),
                            ),
                          ),
                  ),
                );
              },
            ),
          );
        },
      );
    }

    if (widget.fullscreen) {
      return list;
    }

    // In-player card: whole area opens fullscreen
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openFullscreen,
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(child: list),
            Positioned(
              top: 6,
              right: 6,
              child: Icon(
                Icons.open_in_full_rounded,
                size: 18,
                color: cs.onSurface.withOpacity(0.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenLyricsPage extends StatelessWidget {
  final String title;
  final String artist;
  const _FullscreenLyricsPage({required this.title, required this.artist});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          KaraokeLyrics(
            title: title,
            artist: artist,
            expanded: true,
            fullscreen: true,
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: Colors.white70, size: 34),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
