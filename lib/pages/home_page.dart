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
    _load();
    _loadAvatar();
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
    final songs = await SupabaseService.getSongs(limit: 40);
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
                              icon: CircleAvatar(
                                radius: 14,
                                backgroundColor: cs.surfaceContainerHighest,
                                backgroundImage: () {
                                  if (_avatarUrl != null &&
                                      _avatarUrl!.startsWith('http')) {
                                    return NetworkImage(_avatarUrl!);
                                  }
                                  if (_avatarPath != null &&
                                      File(_avatarPath!).existsSync()) {
                                    return FileImage(File(_avatarPath!));
                                  }
                                  return null;
                                }(),
                                child: (_avatarUrl == null &&
                                        (_avatarPath == null ||
                                            !File(_avatarPath ?? '')
                                                .existsSync()))
                                    ? Icon(Icons.person_outline,
                                        size: 16, color: cs.onSurface)
                                    : null,
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
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(isTv ? 28 : 16, 16, 16, 8),
              child: Text('Para ti',
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
                    final title = (s['title'] ?? 'Track').toString();
                    final artist = (s['artist'] ?? '').toString();
                    final cover = (s['cover_url'] ??
                            s['cover'] ??
                            s['image'])
                        ?.toString();
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _play(s, i),
                      onLongPress: () => showSongContextMenu(context, song: s),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: cover != null &&
                                      cover.startsWith('http')
                                  ? Image.network(cover,
                                      fit: BoxFit.cover,
                                      width: double.infinity)
                                  : Container(
                                      color: isTv
                                          ? Colors.white12
                                          : cs.surfaceContainerHighest,
                                      child: Icon(Icons.music_note,
                                          color: isTv
                                              ? Colors.white38
                                              : cs.onSurface
                                                  .withOpacity(0.3)),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isTv
                                      ? Colors.white
                                      : cs.onSurface)),
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
                  },
                  childCount: _songs.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
