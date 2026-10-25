import 'package:flutter/material.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tiles = [
      (Icons.favorite_rounded, 'Liked songs', cs.primary),
      (Icons.download_rounded, 'Downloads', cs.secondary),
      (Icons.playlist_play_rounded, 'Playlists', cs.tertiary),
      (Icons.star_rounded, 'Favorites', cs.primary),
    ];
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
        children: [
          Text('Library',
              style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface)),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
            children: [
              for (final t in tiles)
                Material(
                  color: cs.surfaceContainerHighest.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(t.$1, color: t.$3),
                          const Spacer(),
                          Text(t.$2,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: cs.onSurface)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          Text('Recientes',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface)),
          const SizedBox(height: 8),
          Text('Las canciones que escuches aparecerán aquí.',
              style: TextStyle(color: cs.onSurface.withOpacity(0.45))),
        ],
      ),
    );
  }
}
