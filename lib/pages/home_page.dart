import 'package:pokke/services/catalog_service.dart';
import 'package:flutter/material.dart';
import 'package:pokke/services/supabase_service.dart';
import 'package:pokke/services/player_controller.dart';
import 'package:pokke/widgets/liquid_glass.dart';
import 'package:pokke/screens/settings_screen.dart';
import 'package:pokke/screens/profile_screen.dart';
import 'package:pokke/pages/music_player_page.dart';
import 'package:pokke/adaptive/breakpoints.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:pokke/widgets/song_context_menu.dart';
import 'package:pokke/widgets/tv_home.dart';
import 'package:pokke/widgets/player_route.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _songs = [];
  bool _loading = true;
  double _scroll = 0;
  String? _avatarUrl;
  String? _avatarPath;

  @override
  void initState() {
    super.initState();
    CatalogService.instance.addListener(_onCatalog);
    _load();
    _loadAvatar();
  }

  @override
  void dispose() {
    CatalogService.instance.removeListener(_onCatalog);
    super.dispose();
  }

  void _onCatalog() {
    if (!mounted) return;
    setState(() {
      _songs = List<Map<String, dynamic>>.from(CatalogService.instance.songs);
      _loading = CatalogService.instance.loading;
    });
  }

  Future<void> _loadAvatar() async {
    final pref = await SharedPreferences.getInstance();
    final path = pref.getString('profile_avatar_path');
    final prof = await SupabaseService.getProfile();
    if (!mounted) return;
    setState(() {
      _avatarPath = path;
      _avatarUrl = prof?['avatar_url']?.toString() ??
          prof?['photo_uri']?.toString();
    });
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final songs = await CatalogService.instance.refresh(limit: 60);
    if (mounted) {
      setState(() {
        _songs = songs;
        _loading = false;
      });
    }
  }

  void _openPlayer() {
    final isTv = Breakpoints.of(context) == PokkeFormFactor.tv;
    Navigator.of(context).push(
      PlayerSlideRoute(page: MusicPlayerPage(tvMode: isTv)),
    );
  }

  Future<void> _play(Map<String, dynamic> song, int index) async {
    await PlayerController.instance
        .play(song, asQueue: _songs, index: index);
    if (!mounted) return;
    _openPlayer();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTv = Breakpoints.of(context) == PokkeFormFactor.tv;
    if (isTv) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0B0F),
        body: TvHome(
          songs: _songs,
          loading: _loading,
          onRefresh: _load,
        ),
      );
    }

    final compact = _scroll > 40;

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n.metrics.axis == Axis.vertical) {
          setState(() => _scroll = n.metrics.pixels);
        }
        return false;
      },
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Phone/tablet header only — TV uses shell chrome
          if (!isTv)
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeOutCubic,
                    height: compact ? 48 : 64,
                    child: LiquidGlass(
                      borderRadius:
                          BorderRadius.circular(compact ? 16 : 20),
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 14),
                        child: Row(
                          children: [
                            Text(
                              'Home',
                              style: TextStyle(
                                fontSize: compact ? 18 : 22,
                                fontWeight: FontWeight.w800,
                                color: cs.onSurface,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              tooltip: 'Settings',
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const SettingsScreen()),
                              ),
                              icon: Icon(Icons.settings_outlined,
                                  color: cs.onSurface),
                            ),
                            IconButton(
                              tooltip: 'Profile',
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const ProfileScreen()),
                                );
                                _loadAvatar();
                              },
                              icon: _HeaderAvatar(
                                url: _avatarUrl,
                                path: _avatarPath,
                                color: cs.onSurface,
                                bg: cs.surfaceContainerHighest,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (isTv)
            const SliverToBoxAdapter(child: SizedBox(height: 12)),
          // Greeting
          if (!isTv)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
                child: Text(
                  _greeting(),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ),

          // Horizontal "Escuchado recientemente" / top picks
          if (!_loading && _songs.isNotEmpty)
            ..._horizontalSection(
              context,
              title: 'Populares ahora',
              songs: _songs.take(12).toList(),
              cs: cs,
            ),

          if (!_loading && _songs.length > 6)
            ..._horizontalSection(
              context,
              title: 'Para ti',
              songs: _songs.skip(6).take(12).toList(),
              cs: cs,
            ),

          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(isTv ? 28 : 16, 16, 16, 8),
              child: Text('Hecho para ti',
                  style: TextStyle(
                      fontSize: isTv ? 22 : 18,
                      fontWeight: FontWeight.w800,
                      color: isTv ? Colors.white : cs.onSurface)),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()))
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(isTv ? 24 : 12, 0, isTv ? 24 : 12, 120),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isTv ? 5 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: isTv ? 0.85 : 0.78,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final s = _songs[i];
                    return _songTile(context, s, i, cs, isTv);
                  },
                  childCount: _songs.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 19) return 'Buenas tardes';
    return 'Buenas noches';
  }

  List<Widget> _horizontalSection(
    BuildContext context, {
    required String title,
    required List<Map<String, dynamic>> songs,
    required ColorScheme cs,
  }) {
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Text(title,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface)),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          height: 180,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: songs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final s = songs[i];
              final title = (s['title'] ?? 'Track').toString();
              final artist = (s['artist'] ?? '').toString();
              final cover = (s['cover_url'] ?? s['cover'] ?? s['image'])
                  ?.toString();
              return SizedBox(
                width: 130,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _play(s, i),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: cover != null && cover.startsWith('http')
                              ? Image.network(cover,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => ColoredBox(
                                      color: cs.surfaceContainerHighest,
                                      child: Icon(Icons.music_note,
                                          color: cs.onSurface
                                              .withOpacity(0.3))))
                              : ColoredBox(
                                  color: cs.surfaceContainerHighest,
                                  child: Icon(Icons.music_note,
                                      color:
                                          cs.onSurface.withOpacity(0.3))),
                        ),
                      ),
                      const SizedBox(height: 6),
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
                              color: cs.onSurface.withOpacity(0.5))),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ];
  }

  Widget _songTile(BuildContext context, Map<String, dynamic> s, int i,
      ColorScheme cs, bool isTv) {
    final title = (s['title'] ?? 'Track').toString();
    final artist = (s['artist'] ?? '').toString();
    final cover =
        (s['cover_url'] ?? s['cover'] ?? s['image'])?.toString();
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _play(s, i),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: cover != null && cover.startsWith('http')
                  ? Image.network(cover,
                      fit: BoxFit.cover, width: double.infinity)
                  : Container(
                      color: isTv
                          ? Colors.white12
                          : cs.surfaceContainerHighest,
                      child: Icon(Icons.music_note,
                          color: isTv
                              ? Colors.white38
                              : cs.onSurface.withOpacity(0.3)),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isTv ? Colors.white : cs.onSurface)),
          Text(artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12,
                  color: isTv
                      ? Colors.white54
                      : cs.onSurface.withOpacity(0.5))),
        ],
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  final String? url;
  final String? path;
  final Color color;
  final Color bg;
  const _HeaderAvatar({this.url, this.path, required this.color, required this.bg});

  @override
  Widget build(BuildContext context) {
    ImageProvider? img;
    if (url != null && url!.startsWith('http')) {
      img = NetworkImage(url!);
    } else if (path != null && File(path!).existsSync()) {
      img = FileImage(File(path!));
    }
    return CircleAvatar(
      radius: 14,
      backgroundColor: bg,
      backgroundImage: img,
      child: img == null ? Icon(Icons.person_outline, size: 16, color: color) : null,
    );
  }
}
