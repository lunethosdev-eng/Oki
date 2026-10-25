import 'package:flutter/material.dart';
import 'package:pokke/services/player_controller.dart';
import 'package:pokke/services/devices_service.dart';
import 'package:pokke/services/settings_service.dart';
import 'package:pokke/screens/artist_screen.dart';
import 'package:pokke/widgets/karaoke_lyrics.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MusicPlayerPage extends StatefulWidget {
  final bool tvMode;
  const MusicPlayerPage({super.key, this.tvMode = false});

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage> {
  bool _lyricsExpanded = false;
  bool _showLyrics = false; // TV: only after tapping Lyrics
  bool _following = false;
  bool _dockMode = false;

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
  void initState() {
    super.initState();
    DevicesService.instance.refresh();
  }

  @override
  Widget build(BuildContext context) {
    final pc = PlayerController.instance;
    final cs = Theme.of(context).colorScheme;
    final isTv = widget.tvMode;

    return AnimatedBuilder(
      animation: Listenable.merge([pc, SettingsService.instance, DevicesService.instance]),
      builder: (context, _) {
        final song = pc.current;
        final title = song?['title']?.toString() ?? '—';
        final artist = song?['artist']?.toString() ?? '';
        final cover = song?['cover_url']?.toString() ?? song?['cover']?.toString();
        final dur = pc.duration.inMilliseconds > 0
            ? pc.duration
            : const Duration(seconds: 1);
        final progress =
            (pc.position.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0);
        final bgMode = SettingsService.instance.playerBgMode; // color | blur

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (artist.isNotEmpty) _loadFollow(artist);
        });

        if (isTv) {
          return _tvPlayer(
            context,
            cs,
            pc,
            title: title,
            artist: artist,
            cover: cover,
            progress: progress,
            dur: dur,
            bgMode: bgMode,
          );
        }

        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              // Background from cover
              if (cover != null && cover.startsWith('http'))
                Positioned.fill(
                  child: bgMode == 'blur'
                      ? ImageFiltered(
                          imageFilter: ColorFilter.mode(
                              Colors.black.withOpacity(0.45), BlendMode.darken),
                          child: Image.network(cover, fit: BoxFit.cover),
                        )
                      : DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                cs.primary.withOpacity(0.35),
                                cs.surface,
                              ],
                            ),
                          ),
                        ),
                )
              else
                ColoredBox(color: cs.surface),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                                Icons.keyboard_arrow_down_rounded, size: 32),
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
                            tooltip: _following ? 'Siguiendo' : 'Seguir',
                            onPressed: artist.isEmpty
                                ? null
                                : () => _toggleFollow(artist),
                            icon: Icon(_following
                                ? Icons.person_remove_alt_1_outlined
                                : Icons.person_add_alt_1_outlined),
                          ),
                        ],
                      ),
                      // Connected device strip
                      _deviceChip(cs),
                      if (!_lyricsExpanded) ...[
                        const SizedBox(height: 8),
                        Flexible(
                          flex: 5,
                          child: Hero(
                            tag: 'player_cover',
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
                                : () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ArtistScreen(
                                          name: artist,
                                          imageUrl: cover,
                                        ),
                                      ),
                                    ),
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
                                milliseconds:
                                    (v * dur.inMilliseconds).round()));
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
                            color:
                                cs.surfaceContainerHighest.withOpacity(0.45),
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
            ],
          ),
        );
      },
    );
  }

  Widget _deviceChip(ColorScheme cs) {
    final d = DevicesService.instance.active;
    if (d == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(DevicesService.instance.iconFor(d.type),
              size: 16, color: cs.onSurface.withOpacity(0.55)),
          const SizedBox(width: 6),
          Text(
            d.name,
            style: TextStyle(
                fontSize: 12, color: cs.onSurface.withOpacity(0.55)),
          ),
          if (d.battery != null) ...[
            const SizedBox(width: 8),
            Icon(Icons.battery_std,
                size: 14, color: cs.onSurface.withOpacity(0.45)),
            Text('${d.battery}%',
                style: TextStyle(
                    fontSize: 11, color: cs.onSurface.withOpacity(0.45))),
          ],
        ],
      ),
    );
  }

  /// Spotify-TV-like full player
  Widget _tvPlayer(
    BuildContext context,
    ColorScheme cs,
    PlayerController pc, {
    required String title,
    required String artist,
    required String? cover,
    required double progress,
    required Duration dur,
    required String bgMode,
  }) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (cover != null && cover.startsWith('http'))
            Positioned.fill(
              child: bgMode == 'blur'
                  ? ColorFiltered(
                      colorFilter: ColorFilter.mode(
                          Colors.black.withOpacity(0.4), BlendMode.darken),
                      child: Image.network(cover, fit: BoxFit.cover),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            cs.primary.withOpacity(0.85),
                            cs.primary.withOpacity(0.55),
                            Colors.black87,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
            )
          else
            Container(color: const Color(0xFF1a1a1a)),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(40, 16, 40, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white70),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.settings_outlined,
                            color: Colors.white70),
                      ),
                      const Icon(Icons.account_circle_outlined,
                          color: Colors.white70, size: 28),
                    ],
                  ),
                  const Spacer(),
                  if (_showLyrics)
                    Expanded(
                      flex: 6,
                      child: KaraokeLyrics(
                        title: title,
                        artist: artist,
                        expanded: true,
                      ),
                    )
                  else ...[
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.w700,
                            height: 1.15)),
                    const SizedBox(height: 8),
                    Text(artist,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 20)),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (cover != null && cover.startsWith('http'))
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(cover,
                                width: 48, height: 48, fit: BoxFit.cover),
                          ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                            Text(artist,
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.55),
                                    fontSize: 13)),
                          ],
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 20),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      trackHeight: 3,
                      thumbShape:
                          const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: progress,
                      onChanged: (v) {
                        pc.seek(Duration(
                            milliseconds: (v * dur.inMilliseconds).round()));
                      },
                    ),
                  ),
                  Row(
                    children: [
                      Text(_fmt(pc.position),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                      const Spacer(),
                      Text(_fmt(dur),
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      IconButton(
                        onPressed: pc.previous,
                        icon: const Icon(Icons.skip_previous,
                            color: Colors.white, size: 36),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: pc.toggle,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: const CircleBorder(),
                          padding: const EdgeInsets.all(14),
                        ),
                        child: Icon(
                          pc.playing ? Icons.pause : Icons.play_arrow,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: pc.next,
                        icon: const Icon(Icons.skip_next,
                            color: Colors.white, size: 36),
                      ),
                      IconButton(
                        onPressed: pc.cycleRepeat,
                        icon: Icon(
                          pc.repeatMode == 2
                              ? Icons.repeat_one
                              : Icons.repeat,
                          color: pc.repeatMode > 0
                              ? Colors.white
                              : Colors.white54,
                        ),
                      ),
                      const Spacer(),
                      // Lyrics toggle (TV)
                      OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _showLyrics = !_showLyrics),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                        ),
                        icon: const Icon(Icons.lyrics_outlined, size: 18),
                        label: Text(_showLyrics ? 'Hide lyrics' : 'Lyrics'),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: () =>
                            setState(() => _dockMode = !_dockMode),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                        ),
                        icon: const Icon(Icons.dock_rounded, size: 18),
                        label: Text(_dockMode ? 'Player' : 'Dock mode'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Devices + follow
                  Row(
                    children: [
                      Icon(DevicesService.instance.iconFor(
                              DevicesService.instance.active?.type ??
                                  'speaker'),
                          color: Colors.white70, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        DevicesService.instance.active?.name ??
                            'Dispositivos conectados',
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13),
                      ),
                      if (DevicesService.instance.active?.battery != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '${DevicesService.instance.active!.battery}%',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                      const Spacer(),
                      TextButton.icon(
                        onPressed: artist.isEmpty
                            ? null
                            : () => _toggleFollow(artist),
                        icon: Icon(
                          _following
                              ? Icons.check_circle
                              : Icons.person_add_alt_1,
                          color: Colors.white70,
                          size: 18,
                        ),
                        label: Text(
                          _following ? 'Siguiendo' : 'Seguir artista',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
