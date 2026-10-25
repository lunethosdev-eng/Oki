import 'package:flutter/material.dart';
import 'package:pokke/services/player_controller.dart';
import 'package:pokke/pages/music_player_page.dart';
import 'package:pokke/widgets/liquid_glass.dart';

class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final pc = PlayerController.instance;
    return AnimatedBuilder(
      animation: pc,
      builder: (context, _) {
        final song = pc.current;
        if (song == null) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final title = song['title']?.toString() ?? '';
        final artist = song['artist']?.toString() ?? '';
        final cover = song['cover_url']?.toString();
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MusicPlayerPage()),
            ),
            child: LiquidGlass(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 58,
                child: Row(
                  children: [
                    const SizedBox(width: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: SizedBox(
                        width: 42,
                        height: 42,
                        child: cover != null && cover.startsWith('http')
                            ? Image.network(cover, fit: BoxFit.cover)
                            : ColoredBox(
                                color: cs.surfaceContainerHighest,
                                child: const Icon(Icons.music_note, size: 20),
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
                      icon: Icon(
                          pc.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
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
        );
      },
    );
  }
}
