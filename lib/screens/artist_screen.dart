import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pokke/services/music_api_service.dart';
import 'package:pokke/services/player_controller.dart';
import 'package:pokke/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ArtistScreen extends StatefulWidget {
  final String name;
  final String? imageUrl;
  const ArtistScreen({super.key, required this.name, this.imageUrl});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  List<Map<String, dynamic>> _songs = [];
  bool _loading = true;
  bool _following = false;

  @override
  void initState() {
    super.initState();
    _load();
    _loadFollow();
  }

  Future<void> _loadFollow() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList('followed_artists') ?? [];
    setState(() => _following = list.contains(widget.name.toLowerCase()));
  }

  Future<void> _toggleFollow() async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList('followed_artists') ?? [];
    final key = widget.name.toLowerCase();
    if (_following) {
      list.remove(key);
    } else {
      list.add(key);
    }
    await p.setStringList('followed_artists', list);
    setState(() => _following = !_following);
    // optional: persist to kokoro if logged in
    if (SupabaseService.isLoggedIn && !SupabaseService.isGuest) {
      try {
        await SupabaseService.kokoro.from('follows').upsert({
          'user_id': SupabaseService.currentUser!.id,
          'artist_name': widget.name,
          'following': _following,
        });
      } catch (_) {}
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final songs = await MusicApiService.artistReleases(widget.name);
    // Prefer tracks where artist matches closely
    songs.sort((a, b) {
      final aa = (a['artist'] ?? '').toString().toLowerCase();
      final bb = (b['artist'] ?? '').toString().toLowerCase();
      final n = widget.name.toLowerCase();
      final sa = aa.contains(n) ? 0 : 1;
      final sb = bb.contains(n) ? 0 : 1;
      return sa.compareTo(sb);
    });
    if (mounted) {
      setState(() {
        _songs = songs;
        _loading = false;
      });
    }
  }

  String? _cover(Map s) =>
      (s['cover_url'] ?? s['cover'] ?? s['image'] ?? s['thumbnail'])
          ?.toString();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SettingsAdaptiveAppBar(name: widget.name, imageUrl: widget.imageUrl),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.name,
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.w900)),
                  ),
                  FilledButton.tonal(
                    onPressed: _toggleFollow,
                    child: Text(_following ? 'Siguiendo' : 'Seguir'),
                  ),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
          else if (_songs.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text('Sin canciones aún',
                    style: TextStyle(color: cs.onSurface.withOpacity(0.5))),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final s = _songs[i];
                  final title = (s['title'] ?? 'Track').toString();
                  final artist = (s['artist'] ?? widget.name).toString();
                  final cover = _cover(s);
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: cover != null && cover.startsWith('http')
                          ? CachedNetworkImage(
                              imageUrl: cover,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _placeholder(cs),
                            )
                          : _placeholder(cs),
                    ),
                    title: Text(title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(artist,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    onTap: () => PlayerController.instance
                        .play(s, asQueue: _songs, index: i),
                  );
                },
                childCount: _songs.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
        width: 52,
        height: 52,
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.music_note, color: cs.onSurface.withOpacity(0.3)),
      );
}

class SettingsAdaptiveAppBar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  const SettingsAdaptiveAppBar({super.key, required this.name, this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      flexibleSpace: FlexibleSpaceBar(
        background: imageUrl != null && imageUrl!.startsWith('http')
            ? CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                color: Colors.black26,
                colorBlendMode: BlendMode.darken,
              )
            : Container(
                color: cs.surfaceContainerHighest,
                alignment: Alignment.center,
                child: Icon(Icons.person, size: 72, color: cs.onSurface.withOpacity(0.2)),
              ),
      ),
    );
  }
}
