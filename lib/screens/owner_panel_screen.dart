import 'package:flutter/material.dart';
import 'package:pokke/services/music_api_service.dart';
import 'package:pokke/services/settings_service.dart';
import 'package:pokke/services/supabase_service.dart';

/// Owner-only: music server URL, catalog covers, animated covers.
class OwnerPanelScreen extends StatefulWidget {
  const OwnerPanelScreen({super.key});
  @override
  State<OwnerPanelScreen> createState() => _OwnerPanelScreenState();
}

class _OwnerPanelScreenState extends State<OwnerPanelScreen> {
  final _server = TextEditingController();
  final _coverUrl = TextEditingController();
  final _animUrl = TextEditingController();
  List<Map<String, dynamic>> _songs = [];
  List<Map<String, dynamic>> _noCover = [];
  bool _loading = true;
  String? _selectedId;

  @override
  void initState() {
    super.initState();
    _server.text = SettingsService.instance.musicApiBaseOverride ?? '';
    _load();
  }

  @override
  void dispose() {
    _server.dispose();
    _coverUrl.dispose();
    _animUrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final all = await SupabaseService.getSongs(limit: 200);
    final missing = all.where((s) {
      final c = (s['cover_url'] ?? s['cover'] ?? '').toString();
      return c.isEmpty || !c.startsWith('http');
    }).toList();
    if (mounted) {
      setState(() {
        _songs = all;
        _noCover = missing;
        _loading = false;
      });
    }
  }

  Future<void> _saveServer() async {
    await MusicApiService.setGlobalBase(_server.text);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Servidor guardado')));
    }
  }

  Future<void> _saveCover({bool animated = false}) async {
    if (_selectedId == null) return;
    final url = animated ? _animUrl.text.trim() : _coverUrl.text.trim();
    if (url.isEmpty) return;
    try {
      final data = animated
          ? {'animated_cover_url': url}
          : {'cover_url': url};
      await SupabaseService.ukiyo
          .from('songs')
          .update(data)
          .eq('id', _selectedId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(animated ? 'Cover animado guardado' : 'Cover guardado')),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!SupabaseService.isOwner) {
      return const Scaffold(
        body: Center(child: Text('Solo owner')),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner panel'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Servidor de música',
              style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface)),
          const SizedBox(height: 8),
          TextField(
            controller: _server,
            decoration: const InputDecoration(
              labelText: 'Base URL (Cloudflare tunnel / API)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _saveServer, child: const Text('Guardar URL')),
          const SizedBox(height: 24),
          Text('Catálogo (${_songs.length}) · sin cover: ${_noCover.length}',
              style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface)),
          const SizedBox(height: 8),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else
            ..._noCover.take(40).map((s) {
              final id = s['id']?.toString() ?? '';
              final title = s['title']?.toString() ?? '';
              final artist = s['artist']?.toString() ?? '';
              final selected = _selectedId == id;
              return ListTile(
                selected: selected,
                title: Text(title),
                subtitle: Text(artist),
                onTap: () => setState(() => _selectedId = id),
              );
            }),
          if (_selectedId != null) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _coverUrl,
              decoration: const InputDecoration(
                labelText: 'Cover URL (estático)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => _saveCover(animated: false),
              child: const Text('Guardar cover'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _animUrl,
              decoration: const InputDecoration(
                labelText: 'Cover animado URL (GIF/WebP/MP4)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => _saveCover(animated: true),
              child: const Text('Guardar cover animado'),
            ),
          ],
        ],
      ),
    );
  }
}
