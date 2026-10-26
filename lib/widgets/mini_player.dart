import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pokke/services/player_controller.dart';
import 'package:pokke/pages/music_player_page.dart';
import 'package:pokke/widgets/liquid_glass.dart';
import 'package:pokke/widgets/player_route.dart';
import 'package:pokke/adaptive/breakpoints.dart';

class MiniPlayer extends StatefulWidget {
  const MiniPlayer({super.key});

  @override
  State<MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<MiniPlayer>
    with SingleTickerProviderStateMixin {
  double _dragX = 0;
  double _dragY = 0;
  bool _hidden = false;
  late final AnimationController _hideCtrl;

  @override
  void initState() {
    super.initState();
    _hideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _hideCtrl.dispose();
    super.dispose();
  }

  void _openFull() {
    HapticFeedback.lightImpact();
    Navigator.of(context).push(
      PlayerSlideRoute(
        page: MusicPlayerPage(
          tvMode: Breakpoints.of(context) == PokkeFormFactor.tv,
        ),
      ),
    );
  }

  void _onHorizontal(double dx) {
    if (dx.abs() < 56) return;
    HapticFeedback.selectionClick();
    if (dx < 0) {
      PlayerController.instance.next();
    } else {
      PlayerController.instance.previous();
    }
    setState(() => _dragX = 0);
  }

  void _onVertical(double dy) {
    if (dy < -40) {
      _openFull();
    } else if (dy > 48) {
      HapticFeedback.mediumImpact();
      setState(() => _hidden = true);
      _hideCtrl.forward();
    }
    setState(() => _dragY = 0);
  }

  @override
  Widget build(BuildContext context) {
    final pc = PlayerController.instance;
    return AnimatedBuilder(
      animation: Listenable.merge([pc, _hideCtrl]),
      builder: (context, _) {
        final song = pc.current;
        if (song == null) return const SizedBox.shrink();
        if (_hidden) {
          return Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(right: 12, bottom: 4),
              child: IconButton.filledTonal(
                onPressed: () {
                  setState(() => _hidden = false);
                  _hideCtrl.reverse();
                },
                icon: const Icon(Icons.music_note_rounded),
              ),
            ),
          );
        }
        final cs = Theme.of(context).colorScheme;
        final title = song['title']?.toString() ?? '';
        final artist = song['artist']?.toString() ?? '';
        final cover = song['cover_url']?.toString() ?? song['cover']?.toString();

        return AnimatedSlide(
          duration: const Duration(milliseconds: 280),
          offset: Offset(_dragX / 300, _dragY / 200),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: (1 - (_dragY.abs() / 180)).clamp(0.4, 1.0),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: GestureDetector(
                onTap: _openFull,
                onHorizontalDragUpdate: (d) =>
                    setState(() => _dragX += d.delta.dx),
                onHorizontalDragEnd: (_) => _onHorizontal(_dragX),
                onVerticalDragUpdate: (d) =>
                    setState(() => _dragY += d.delta.dy),
                onVerticalDragEnd: (_) => _onVertical(_dragY),
                child: LiquidGlass(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    height: 58,
                    child: Row(
                      children: [
                        const SizedBox(width: 8),
                        Hero(
                          tag: 'player_cover',
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 42,
                              height: 42,
                              child: cover != null && cover.startsWith('http')
                                  ? Image.network(cover, fit: BoxFit.cover)
                                  : ColoredBox(
                                      color: cs.surfaceContainerHighest,
                                      child: const Icon(Icons.music_note,
                                          size: 20),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurface)),
                              Text(artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: cs.onSurface.withOpacity(0.45))),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: pc.toggle,
                          icon: Icon(pc.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded),
                        ),
                        IconButton(
                          onPressed: pc.next,
                          icon: const Icon(Icons.skip_next_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
