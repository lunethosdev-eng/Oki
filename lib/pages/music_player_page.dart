import 'package:flutter/material.dart';
import 'package:pokke/services/player_controller.dart';
import 'package:pokke/screens/artist_screen.dart';
import 'package:pokke/widgets/karaoke_lyrics.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MusicPlayerPage extends StatefulWidget {
  const MusicPlayerPage({super.key});

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage> {
  bool _lyricsExpanded = false;
  bool _following = false;

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString();
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _loadFollow(String artist) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList('followed_artists') ?? [];
    if (mounted) {
      setState(() => _following = list.contains(artist.toLowerCase()));
    }
  }

  Future<void> _toggleFollow(String artist) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList('followed_artists') ?? [];
    final key = artist.toLowerCase();
    if (_following) {
      list.remove(key);
    } else {
      list.add(key);
    }
    await p.setStringList('followed_artists', list);
    setState(() => _following = !_following);
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
        final cover = song?['cover_url']?.toString() ??
            song?['cover']?.toString();
        final dur = pc.duration.inMilliseconds > 0
            ? pc.duration
            : const Duration(seconds: 1);
        final progress =
            (pc.position.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);

        // refresh follow when track changes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (artist.isNotEmpty) _loadFollow(artist);
        });

        return Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
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
                      IconButton(
                        tooltip: _following ? 'Siguiendo' : 'Seguir artista',
                        onPressed: artist.isEmpty
                            ? null
                            : () => _toggleFollow(artist),
                        icon: Icon(
                          _following
                              ? Icons.person_remove_alt_1_outlined
                              : Icons.person_add_alt_1_outlined,
                        ),
                      ),
                    ],
                  ),
                  if (!_lyricsExpanded) ...[
                    const SizedBox(height: 8),
                    Flexible(
                      flex: 5,
                      child: AspectRatio(
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
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(title,
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: cs.onSurface)),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: InkWell(
                        onTap: artist.isEmpty
                            ? null
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ArtistScreen(
                                      name: artist,
                                      imageUrl: cover,
                                    ),
                                  ),
                                );
                              },
                        child: Text(artist,
                            style: TextStyle(
                                fontSize: 15,
                                color: cs.primary.withOpacity(0.9))),
                      ),
                    ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: pc.toggleShuffle,
                          icon: Icon(Icons.shuffle,
                              color: pc.shuffle
                                  ? cs.primary
                                  : cs.onSurface.withOpacity(0.4)),
                        ),
                        IconButton(
                          onPressed: pc.previous,
                          icon: const Icon(Icons.skip_previous, size: 36),
                        ),
                        FilledButton(
                          onPressed: pc.toggle,
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(16),
                          ),
                          child: Icon(
                            pc.playing ? Icons.pause : Icons.play_arrow,
                            size: 32,
                          ),
                        ),
                        IconButton(
                          onPressed: pc.next,
                          icon: const Icon(Icons.skip_next, size: 36),
                        ),
                        IconButton(
                          onPressed: pc.cycleRepeat,
                          icon: Icon(
                            pc.repeatMode == 2
                                ? Icons.repeat_one
                                : Icons.repeat,
                            color: pc.repeatMode > 0
                                ? cs.primary
                                : cs.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 8),
                  Expanded(
                    flex: _lyricsExpanded ? 12 : 4,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic,
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: song == null
                          ? const SizedBox.shrink()
                          : KaraokeLyrics(
                              title: title,
                              artist: artist,
                              expanded: _lyricsExpanded,
                              onExpandToggle: () => setState(
                                  () => _lyricsExpanded = !_lyricsExpanded),
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
