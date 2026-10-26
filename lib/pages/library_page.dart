import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pokke/services/player_controller.dart';
import 'package:pokke/pages/music_player_page.dart';
import 'package:pokke/widgets/player_route.dart';
import 'package:pokke/adaptive/breakpoints.dart';

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});
  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<Map<String, dynamic>> _playlists = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('playlists_v1');
    if (raw == null) return;
    final list = jsonDecode(raw) as List;
    setState(() {
      _playlists =
          list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('playlists_v1', jsonEncode(_playlists));
  }

  Future<void> _create() async {
    final nameCtrl = TextEditingController();
    String? coverPath;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setL) => AlertDialog(
          title: const Text('Nueva playlist'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final x = await ImagePicker().pickImage(
                      source: ImageSource.gallery, imageQuality: 85);
                  if (x != null) setL(() => coverPath = x.path);
                },
                icon: const Icon(Icons.image_outlined),
                label: Text(coverPath == null ? 'Cover / GIF' : 'Cover listo'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Crear')),
          ],
        ),
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    setState(() {
      _playlists.insert(0, {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'name': nameCtrl.text.trim(),
        'cover': coverPath,
        'songs': <dynamic>[],
      });
    });
    await _save();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: const Text('Library'),
            actions: [
              IconButton(icon: const Icon(Icons.add), onPressed: _create),
            ],
          ),
          if (_playlists.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Text(
                  'Sin playlists.\nToca + para crear una con cover/GIF.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: cs.onSurface.withOpacity(0.45)),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final pl = _playlists[i];
                    final songs = (pl['songs'] as List?) ?? [];
                    final cover = pl['cover']?.toString();
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: cover != null && File(cover).existsSync()
                              ? Image.file(File(cover), fit: BoxFit.cover)
                              : ColoredBox(
                                  color: cs.surfaceContainerHighest,
                                  child: const Icon(Icons.queue_music),
                                ),
                        ),
                      ),
                      title: Text(pl['name']?.toString() ?? 'Playlist',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${songs.length} canciones'),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlaylistDetailPage(
                              playlist: pl,
                              onChanged: (u) async {
                                final ix = _playlists
                                    .indexWhere((e) => e['id'] == u['id']);
                                if (ix >= 0) {
                                  setState(() => _playlists[ix] = u);
                                  await _save();
                                }
                              },
                            ),
                          ),
                        );
                        _load();
                      },
                    );
                  },
                  childCount: _playlists.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        child: const Icon(Icons.add),
      ),
    );
  }
}

class PlaylistDetailPage extends StatefulWidget {
  final Map<String, dynamic> playlist;
  final ValueChanged<Map<String, dynamic>> onChanged;
  const PlaylistDetailPage(
      {super.key, required this.playlist, required this.onChanged});

  @override
  State<PlaylistDetailPage> createState() => _PlaylistDetailPageState();
}

class _PlaylistDetailPageState extends State<PlaylistDetailPage> {
  late List<Map<String, dynamic>> _songs;

  @override
  void initState() {
    super.initState();
    _songs = ((widget.playlist['songs'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  void _persist() {
    widget.playlist['songs'] = _songs;
    widget.onChanged(widget.playlist);
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.playlist['name']?.toString() ?? 'Playlist';
    return Scaffold(
      appBar: AppBar(
        title: Text(name),
        actions: [
          if (_songs.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () async {
                await PlayerController.instance
                    .play(_songs.first, asQueue: _songs, index: 0);
                if (!mounted) return;
                final isTv =
                    Breakpoints.of(context) == PokkeFormFactor.tv;
                Navigator.of(context).push(
                  PlayerSlideRoute(page: MusicPlayerPage(tvMode: isTv)),
                );
              },
            ),
        ],
      ),
      body: _songs.isEmpty
          ? const Center(
              child: Text(
                  'Vacía. Usa “Agregar a playlist” desde el menú ⋮ de una canción.'))
          : ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
              itemCount: _songs.length,
              onReorder: (a, b) {
                setState(() {
                  if (b > a) b--;
                  final item = _songs.removeAt(a);
                  _songs.insert(b, item);
                });
                _persist();
              },
              itemBuilder: (_, i) {
                final s = _songs[i];
                return ListTile(
                  key: ValueKey('${s['id']}_$i'),
                  leading: const Icon(Icons.drag_handle),
                  title: Text(s['title']?.toString() ?? 'Track'),
                  subtitle: Text(s['artist']?.toString() ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () {
                      setState(() => _songs.removeAt(i));
                      _persist();
                    },
                  ),
                  onTap: () async {
                    await PlayerController.instance
                        .play(s, asQueue: _songs, index: i);
                    if (!mounted) return;
                    final isTv =
                        Breakpoints.of(context) == PokkeFormFactor.tv;
                    Navigator.of(context).push(
                      PlayerSlideRoute(page: MusicPlayerPage(tvMode: isTv)),
                    );
                  },
                );
              },
            ),
    );
  }
}
