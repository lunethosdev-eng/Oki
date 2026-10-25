import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pokke/services/music_api_service.dart';
import 'package:pokke/services/settings_service.dart';
import 'package:pokke/services/player_controller.dart';
import 'package:pokke/services/supabase_service.dart';
import 'package:pokke/screens/artist_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  List<Map<String, dynamic>> _suggestions = [];
  Map<String, dynamic>? _artistHit;
  List<String> _history = [];
  bool _loading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    if (!SettingsService.instance.saveSearchHistory) return;
    final p = await SharedPreferences.getInstance();
    setState(() => _history = p.getStringList('search_history') ?? []);
  }

  Future<void> _saveHistory(String q) async {
    if (!SettingsService.instance.saveSearchHistory) return;
    final p = await SharedPreferences.getInstance();
    final list = [q, ..._history.where((e) => e != q)].take(12).toList();
    await p.setStringList('search_history', list);
    setState(() => _history = list);
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      if (v.trim().length < 2) {
        if (mounted) setState(() => _suggestions = []);
        return;
      }
      final s = await MusicApiService.autocomplete(v);
      if (mounted) setState(() => _suggestions = s);
    });
  }

  Future<void> _search(String raw) async {
    final q = raw.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _results = [];
      _artistHit = null;
      _suggestions = [];
    });
    await _saveHistory(q);

    // Parallel: catalog search + artist guess
    final songsFuture = MusicApiService.search(q);
    final artistsFuture = SupabaseService.getArtists(limit: 80);

    final songs = await songsFuture;
    List<Map<String, dynamic>> artists = [];
    try {
      artists = await artistsFuture;
    } catch (_) {}

    Map<String, dynamic>? artistHit;
    final ql = q.toLowerCase();
    for (final a in artists) {
      final name = (a['name'] ?? a['artist'] ?? '').toString();
      if (name.toLowerCase() == ql || name.toLowerCase().startsWith(ql)) {
        artistHit = {
          'name': name,
          'image_url': a['image_url'] ?? a['cover_url'] ?? a['avatar'],
          'is_artist': true,
        };
        break;
      }
    }
    // If no artists table hit, synthesize from first song artist match
    if (artistHit == null && songs.isNotEmpty) {
      for (final s in songs) {
        final art = (s['artist'] ?? '').toString();
        if (art.toLowerCase() == ql || art.toLowerCase().startsWith(ql)) {
          artistHit = {
            'name': art,
            'image_url': s['cover_url'] ?? s['cover'],
            'is_artist': true,
          };
          break;
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _results = songs;
      _artistHit = artistHit;
      _loading = false;
    });
  }

  String? _cover(Map s) =>
      (s['cover_url'] ?? s['cover'] ?? s['image'] ?? s['thumbnail'] ?? s['artwork'])
          ?.toString();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final empty = _results.isEmpty && _artistHit == null && !_loading;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _ctrl,
                onChanged: _onChanged,
                onSubmitted: _search,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Canción, artista o link…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _ctrl.text.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() {
                              _results = [];
                              _artistHit = null;
                              _suggestions = [];
                            });
                          },
                        ),
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withOpacity(0.55),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            if (_suggestions.isNotEmpty && _results.isEmpty && !_loading)
              SizedBox(
                height: 42,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _suggestions.length.clamp(0, 12),
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final s = _suggestions[i];
                    final label =
                        (s['title'] ?? s['name'] ?? s['query'] ?? s).toString();
                    return ActionChip(
                      label: Text(label, overflow: TextOverflow.ellipsis),
                      onPressed: () {
                        _ctrl.text = label;
                        _search(label);
                      },
                    );
                  },
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : empty
                      ? ListView(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                          children: [
                            if (_history.isNotEmpty) ...[
                              Text('Recientes',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: cs.onSurface)),
                              const SizedBox(height: 8),
                              for (final h in _history)
                                ListTile(
                                  leading: Icon(Icons.history,
                                      color: cs.onSurface.withOpacity(0.4)),
                                  title: Text(h),
                                  onTap: () {
                                    _ctrl.text = h;
                                    _search(h);
                                  },
                                ),
                            ] else
                              Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  'Busca por nombre, artista o pega un link.\nSi no está en el catálogo, el servidor la descarga.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: cs.onSurface.withOpacity(0.45),
                                      height: 1.4),
                                ),
                              ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 140),
                          itemCount: _results.length + (_artistHit != null ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (_artistHit != null && i == 0) {
                              final a = _artistHit!;
                              final img = a['image_url']?.toString();
                              return Card(
                                margin: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.all(12),
                                  leading: CircleAvatar(
                                    radius: 28,
                                    backgroundImage: img != null &&
                                            img.startsWith('http')
                                        ? CachedNetworkImageProvider(img)
                                        : null,
                                    child: img == null || !img.startsWith('http')
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  title: Text(a['name']?.toString() ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 17)),
                                  subtitle: const Text('Artista'),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ArtistScreen(
                                          name: a['name']?.toString() ?? '',
                                          imageUrl: img,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              );
                            }
                            final idx = _artistHit != null ? i - 1 : i;
                            final s = _results[idx];
                            final title = (s['title'] ?? 'Track').toString();
                            final artist = (s['artist'] ?? '').toString();
                            final cover = _cover(s);
                            return ListTile(
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: cover != null && cover.startsWith('http')
                                    ? CachedNetworkImage(
                                        imageUrl: cover,
                                        width: 56,
                                        height: 56,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) =>
                                            _ph(cs),
                                        errorWidget: (_, __, ___) =>
                                            _ph(cs),
                                      )
                                    : _ph(cs),
                              ),
                              title: Text(title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              onTap: () => PlayerController.instance
                                  .play(s, asQueue: _results, index: idx),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _ph(ColorScheme cs) => Container(
        width: 56,
        height: 56,
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.music_note, color: cs.onSurface.withOpacity(0.3)),
      );
}
