import 'package:flutter/material.dart';
import 'package:pokke/services/player_controller.dart';
import 'package:pokke/widgets/karaoke_lyrics.dart';

class MusicPlayerPage extends StatelessWidget {
  const MusicPlayerPage({super.key});

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(1, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final pc = PlayerController.instance;
    final cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: pc,
      builder: (context, _) {
        final song = pc.current;
        final title = song?['title']?.toString() ?? '—';
        final artist = song?['artist']?.toString() ?? '';
        final cover = song?['cover_url']?.toString();
        final dur = pc.duration.inMilliseconds > 0
            ? pc.duration
            : const Duration(seconds: 1);
        final progress =
            (pc.position.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 32),
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            Text('REPRODUCIENDO',
                                style: TextStyle(
                                    fontSize: 11,
                                    letterSpacing: 1.4,
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurface.withOpacity(0.45))),
                            Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: cs.onSurface)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                  const Spacer(),
                  AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: cover != null && cover.startsWith('http')
                          ? Image.network(cover, fit: BoxFit.cover)
                          : ColoredBox(
                              color: cs.surfaceContainerHighest,
                              child: Icon(Icons.album,
                                  size: 80,
                                  color: cs.onSurface.withOpacity(0.2)),
                            ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: cs.onSurface)),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(artist,
                        style: TextStyle(
                            fontSize: 16,
                            color: cs.onSurface.withOpacity(0.5))),
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: progress,
                    onChanged: (v) {
                      pc.seek(Duration(
                          milliseconds: (v * dur.inMilliseconds).round()));
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_fmt(pc.position),
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withOpacity(0.45))),
                      Text(_fmt(dur),
                          style: TextStyle(
                              fontSize: 12,
                              color: cs.onSurface.withOpacity(0.45))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        onPressed: pc.toggleShuffle,
                        icon: Icon(Icons.shuffle_rounded,
                            color: pc.shuffle
                                ? cs.primary
                                : cs.onSurface.withOpacity(0.45)),
                      ),
                      IconButton(
                        onPressed: pc.previous,
                        iconSize: 36,
                        icon: const Icon(Icons.skip_previous_rounded),
                      ),
                      FilledButton(
                        onPressed: pc.toggle,
                        style: FilledButton.styleFrom(
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(16),
                        ),
                        child: Icon(
                          pc.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 36,
                        ),
                      ),
                      IconButton(
                        onPressed: pc.next,
                        iconSize: 36,
                        icon: const Icon(Icons.skip_next_rounded),
                      ),
                      IconButton(
                        onPressed: pc.cycleRepeat,
                        icon: Icon(
                          pc.repeatMode == 2
                              ? Icons.repeat_one_rounded
                              : Icons.repeat_rounded,
                          color: pc.repeatMode == 0
                              ? cs.onSurface.withOpacity(0.45)
                              : cs.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Letras',
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface)),
                          const SizedBox(height: 4),
                          Expanded(
                            child: song == null
                                ? const SizedBox.shrink()
                                : KaraokeLyrics(
                                    title: title,
                                    artist: artist,
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
