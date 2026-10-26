import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:pokke/services/settings_service.dart';
import 'package:pokke/services/player_controller.dart';
import 'package:pokke/pages/music_player_page.dart';
import 'package:pokke/widgets/player_route.dart';
import 'package:pokke/widgets/song_context_menu.dart';
import 'package:pokke/screens/settings_screen.dart';
import 'package:pokke/screens/profile_screen.dart';

/// Spotify-TV-like home: hero + chips + grid with D-pad focus.
class TvHome extends StatefulWidget {
  final List<Map<String, dynamic>> songs;
  final bool loading;
  final VoidCallback onRefresh;
  const TvHome({
    super.key,
    required this.songs,
    required this.loading,
    required this.onRefresh,
  });

  @override
  State<TvHome> createState() => _TvHomeState();
}

class _TvHomeState extends State<TvHome> {
  VideoPlayerController? _heroVid;
  int _chip = 0;
  final _chips = const ['All', 'Music', 'Podcasts'];

  @override
  void initState() {
    super.initState();
    _initHero();
  }

  Future<void> _initHero() async {
    final path = SettingsService.instance.heroMediaPath;
    if (path == null || path.isEmpty) return;
    final type = SettingsService.instance.heroMediaType;
    final isVid = type == 'video' ||
        path.toLowerCase().endsWith('.mp4') ||
        path.toLowerCase().endsWith('.webm');
    if (!isVid) return;
    try {
      if (path.startsWith('http')) {
        _heroVid = VideoPlayerController.networkUrl(Uri.parse(path));
      } else if (File(path).existsSync()) {
        _heroVid = VideoPlayerController.file(File(path));
      }
      await _heroVid?.initialize();
      await _heroVid?.setLooping(true);
      await _heroVid?.setVolume(0);
      await _heroVid?.play();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _heroVid?.dispose();
    super.dispose();
  }

  Future<void> _play(Map<String, dynamic> s, int i) async {
    await PlayerController.instance
        .play(s, asQueue: widget.songs, index: i);
    if (!mounted) return;
    Navigator.of(context).push(
      PlayerSlideRoute(page: const MusicPlayerPage(tvMode: true)),
    );
  }

  Widget _focusable({
    required Widget child,
    required VoidCallback onSelect,
    BorderRadius? radius,
  }) {
    return FocusableActionDetector(
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            onSelect();
            return null;
          },
        ),
      },
      child: Builder(
        builder: (ctx) {
          final focused = Focus.of(ctx).hasFocus;
          return AnimatedScale(
            scale: focused ? 1.05 : 1.0,
            duration: const Duration(milliseconds: 160),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                borderRadius: radius ?? BorderRadius.circular(12),
                border: focused
                    ? Border.all(color: Colors.white, width: 2.5)
                    : null,
                boxShadow: focused
                    ? [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.18),
                          blurRadius: 18,
                        )
                      ]
                    : null,
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heroSong = widget.songs.isNotEmpty ? widget.songs.first : null;
    final heroPath = SettingsService.instance.heroMediaPath;
    final heroSize = SettingsService.instance.heroSize; // small|medium|large
    final aspect = switch (heroSize) {
      'small' => 3.2,
      'large' => 1.8,
      _ => 2.4, // medium
    };
    final cover = heroSong?['cover_url']?.toString() ??
        heroSong?['cover']?.toString();

    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.select): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.gameButtonA): ActivateIntent(),
      },
      child: CustomScrollView(
        slivers: [
          // Top chrome lives in AdaptiveShell only
          // Hero
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 8, 32, 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: AspectRatio(
                  aspectRatio: aspect,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (_heroVid != null &&
                          _heroVid!.value.isInitialized)
                        FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _heroVid!.value.size.width,
                            height: _heroVid!.value.size.height,
                            child: VideoPlayer(_heroVid!),
                          ),
                        )
                      else if (heroPath != null &&
                          (heroPath.startsWith('http') ||
                              File(heroPath).existsSync()))
                        heroPath.startsWith('http')
                            ? Image.network(heroPath, fit: BoxFit.cover)
                            : Image.file(File(heroPath), fit: BoxFit.cover)
                      else if (cover != null && cover.startsWith('http'))
                        Image.network(cover, fit: BoxFit.cover)
                      else
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFF1a1a2e), Color(0xFF0f0f14)],
                            ),
                          ),
                        ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.black.withOpacity(0.75),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(28),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  heroSong?['title']?.toString() ??
                                      'Para ti',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 36,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  heroSong?['artist']?.toString() ??
                                      'Descubre música en Pokke',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                if (heroSong != null)
                                  _focusable(
                                    onSelect: () => _play(heroSong, 0),
                                    radius: BorderRadius.circular(24),
                                    child: FilledButton.icon(
                                      onPressed: () => _play(heroSong, 0),
                                      icon: const Icon(Icons.play_arrow),
                                      label: const Text('Reproducir'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 12),
              child: Row(
                children: [
                  for (var i = 0; i < _chips.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: _focusable(
                        onSelect: () => setState(() => _chip = i),
                        radius: BorderRadius.circular(20),
                        child: ChoiceChip(
                          label: Text(_chips[i]),
                          selected: _chip == i,
                          onSelected: (_) => setState(() => _chip = i),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Grid
          if (widget.loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(32, 0, 32, 80),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final s = widget.songs[i];
                    final c = (s['cover_url'] ?? s['cover'])?.toString();
                    final title = s['title']?.toString() ?? '';
                    final artist = s['artist']?.toString() ?? '';
                    return _focusable(
                      onSelect: () => _play(s, i),
                      child: InkWell(
                        onTap: () => _play(s, i),
                        onLongPress: () =>
                            showSongContextMenu(context, song: s),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: c != null && c.startsWith('http')
                                    ? Image.network(c, fit: BoxFit.cover,
                                        width: double.infinity)
                                    : Container(
                                        color: Colors.white12,
                                        child: const Icon(Icons.music_note,
                                            color: Colors.white38),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600)),
                            Text(artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 12)),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: widget.songs.length.clamp(0, 40),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

