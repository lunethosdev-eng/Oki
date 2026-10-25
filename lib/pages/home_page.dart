import 'package:flutter/material.dart';
import 'package:pokke/services/supabase_service.dart';
import 'package:pokke/services/player_controller.dart';
import 'package:pokke/widgets/liquid_glass.dart';
import 'package:pokke/screens/settings_screen.dart';
import 'package:pokke/screens/profile_screen.dart';
import 'package:pokke/pages/music_player_page.dart';
import 'package:pokke/adaptive/responsive.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _songs = [];
  bool _loading = true;
  double _scroll = 0;

  @override
  void initState() {
    super.initState();
    _load();
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

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
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
                    borderRadius: BorderRadius.circular(compact ? 16 : 20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
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
                                  builder: (_) => const SettingsScreen()),
                            ),
                            icon: Icon(Icons.settings_outlined,
                                color: cs.onSurface.withOpacity(0.7)),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ProfileScreen()),
                            ),
                            child: CircleAvatar(
                              radius: compact ? 14 : 16,
                              backgroundColor: cs.surfaceContainerHighest,
                              child: Icon(Icons.person,
                                  size: compact ? 16 : 18,
                                  color: cs.onSurface.withOpacity(0.6)),
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
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('Para ti',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: cs.onSurface)),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (_loading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (_songs.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Sin canciones en catálogo todavía.\nUsa Search para encontrar música.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurface.withOpacity(0.45)),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 140),
              sliver: SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: gridColumns(context),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, i) {
                    final s = _songs[i];
                    final title = s['title']?.toString() ?? 'Track';
                    final artist = s['artist']?.toString() ?? '';
                    final cover = s['cover_url']?.toString();
                    return InkWell(
                      onTap: () async {
                        await PlayerController.instance
                            .playSong(s, asQueue: _songs);
                        if (context.mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const MusicPlayerPage()),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: cover != null && cover.startsWith('http')
                                  ? Image.network(cover,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      errorBuilder: (_, __, ___) =>
                                          _coverPh(cs))
                                  : _coverPh(cs),
                            ),
                          ),
                          const SizedBox(height: 8),
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
                    );
                  },
                  childCount: _songs.length.clamp(0, 20),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _coverPh(ColorScheme cs) => Container(
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.music_note, color: cs.onSurface.withOpacity(0.25)),
      );
}
