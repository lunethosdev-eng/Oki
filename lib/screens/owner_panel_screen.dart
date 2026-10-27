import 'package:pokke/services/catalog_service.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pokke/services/music_api_service.dart';
import 'package:pokke/services/settings_service.dart';
import 'package:pokke/services/supabase_service.dart';

class OwnerPanelScreen extends StatefulWidget {
  const OwnerPanelScreen({super.key});
  @override
  State<OwnerPanelScreen> createState() => _OwnerPanelScreenState();
}

class _OwnerPanelScreenState extends State<OwnerPanelScreen> {
  final _server = TextEditingController();
  final _coverUrl = TextEditingController();
  final _animUrl = TextEditingController();
  final _search = TextEditingController();
  List<Map<String, dynamic>> _songs = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  bool _onlyMissing = true;
  String? _selectedId;
  String? _selectedTitle;

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
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // fetch in chunks
    final all = <Map<String, dynamic>>[];
    var batch = await SupabaseService.getSongs(limit: 500);
    all.addAll(batch);
    if (mounted) {
      setState(() {
        _songs = all;
        _applyFilter();
        _loading = false;
      });
    }
  }

  void _applyFilter() {
    final q = _search.text.trim().toLowerCase();
    _filtered = _songs.where((s) {
      final c = (s['cover_url'] ?? s['cover'] ?? '').toString();
      final missing = c.isEmpty || !c.startsWith('http');
      if (_onlyMissing && !missing) return false;
      if (q.isEmpty) return true;
      final title = (s['title'] ?? '').toString().toLowerCase();
      final artist = (s['artist'] ?? '').toString().toLowerCase();
      return title.contains(q) || artist.contains(q);
    }).toList();
  }

  Future<void> _saveServer() async {
    await MusicApiService.setGlobalBase(_server.text);
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Servidor guardado')));
    }
  }

  Future<void> _pickAndUpload({required bool animated}) async {
    if (_selectedId == null) return;
    final picker = ImagePicker();
    // Prefer video for animated covers; still allow images
    XFile? x;
    if (animated) {
      x = await picker.pickVideo(source: ImageSource.gallery);
      x ??= await picker.pickImage(
          source: ImageSource.gallery, maxWidth: 1600, imageQuality: 90);
    } else {
      x = await picker.pickImage(
          source: ImageSource.gallery, maxWidth: 1600, imageQuality: 90);
      // also allow mp4 as static cover if user wants looping art
      x ??= await picker.pickVideo(source: ImageSource.gallery);
    }
    if (x == null) return;
    try {
      final bytes = await File(x.path).readAsBytes();
      final lower = x.path.toLowerCase();
      final isMp4 = lower.endsWith('.mp4') ||
          lower.endsWith('.webm') ||
          lower.endsWith('.mov') ||
          (x.mimeType?.startsWith('video/') ?? false);
      final ext = isMp4
          ? (lower.endsWith('.webm')
              ? 'webm'
              : lower.endsWith('.mov')
                  ? 'mov'
                  : 'mp4')
          : (lower.endsWith('.png')
              ? 'png'
              : lower.endsWith('.webp')
                  ? 'webp'
                  : lower.endsWith('.gif')
                      ? 'gif'
                      : 'jpg');
      final contentType = isMp4
          ? (ext == 'webm' ? 'video/webm' : 'video/mp4')
          : (ext == 'png'
              ? 'image/png'
              : ext == 'webp'
                  ? 'image/webp'
                  : ext == 'gif'
                      ? 'image/gif'
                      : 'image/jpeg');
      final name =
          'covers/${_selectedId}_${animated ? 'anim' : 'static'}_${DateTime.now().millisecondsSinceEpoch}.$ext';

      Future<String> uploadTo(dynamic storage) async {
        try {
          await storage.remove([name]);
        } catch (_) {}
        await storage.uploadBinary(name, bytes);
        return storage.getPublicUrl(name) as String;
      }

      String url;
      try {
        final storage = SupabaseService.ukiyo.storage.from('covers');
        url = await uploadTo(storage);
      } catch (e) {
        final fb = SupabaseService.kokoro.storage.from('covers');
        url = await uploadTo(fb);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Cover vía Kokoro (Ukiyo falló): $e')),
          );
        }
      }

      final data = animated
          ? {'animated_cover_url': url}
          : {'cover_url': url};
      await SupabaseService.ukiyo
          .from('songs')
          .update(data)
          .eq('id', _selectedId!);
      CatalogService.instance.bump();
      if (animated) {
        _animUrl.text = url;
      } else {
        _coverUrl.text = url;
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(animated
                  ? (isMp4
                      ? 'Cover animado MP4 subido (loop)'
                      : 'Cover animado subido')
                  : (isMp4
                      ? 'Cover MP4 subido (loop)'
                      : 'Cover subido desde galería'))),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload: $e')));
      }
    }
  }

  Future<void> _saveCover({required bool animated}) async {
    if (_selectedId == null) return;
    final url = animated ? _animUrl.text.trim() : _coverUrl.text.trim();
    if (url.isEmpty) return;
    try {
      final data =
          animated ? {'animated_cover_url': url} : {'cover_url': url};
      await SupabaseService.ukiyo
          .from('songs')
          .update(data)
          .eq('id', _selectedId!);
        CatalogService.instance.bump();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(animated ? 'Cover animado guardado' : 'Cover guardado')),
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
      return const Scaffold(body: Center(child: Text('Solo owner')));
    }
    final cs = Theme.of(context).colorScheme;
    final missing = _songs.where((s) {
      final c = (s['cover_url'] ?? s['cover'] ?? '').toString();
      return c.isEmpty || !c.startsWith('http');
    }).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Owner panel'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          Text('Servidor de música',
              style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface)),
          const SizedBox(height: 8),
          TextField(
            controller: _server,
            decoration: const InputDecoration(
              labelText: 'Base URL API',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
              onPressed: _saveServer, child: const Text('Guardar URL')),
          const SizedBox(height: 20),
          Text('Catálogo (${_songs.length}) · sin cover: $missing',
              style: TextStyle(fontWeight: FontWeight.w800, color: cs.onSurface)),
          const SizedBox(height: 8),
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Buscar título / artista',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (_) => setState(_applyFilter),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Solo sin cover'),
            value: _onlyMissing,
            onChanged: (v) => setState(() {
              _onlyMissing = v;
              _applyFilter();
            }),
          ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            ..._filtered.take(300).map((s) {
              final id = s['id']?.toString() ?? '';
              final title = s['title']?.toString() ?? '';
              final artist = s['artist']?.toString() ?? '';
              final selected = _selectedId == id;
              final hasAnim =
                  (s['animated_cover_url'] ?? '').toString().startsWith('http');
              return ListTile(
                selected: selected,
                title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(artist),
                trailing: hasAnim
                    ? const Icon(Icons.gif_box_outlined, size: 18)
                    : null,
                onTap: () => setState(() {
                  _selectedId = id;
                  _selectedTitle = title;
                  _coverUrl.text = (s['cover_url'] ?? '').toString();
                  _animUrl.text = (s['animated_cover_url'] ?? '').toString();
                }),
              );
            }),
          if (_selectedId != null) ...[
            const Divider(),
            Text('Editando: $_selectedTitle',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _coverUrl,
              decoration: const InputDecoration(
                labelText: 'Cover URL',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => _saveCover(animated: false),
                    child: const Text('Guardar URL'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickAndUpload(animated: false),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Galería'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _animUrl,
              decoration: const InputDecoration(
                labelText: 'Cover animado URL (GIF/WebP)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => _saveCover(animated: true),
                    child: const Text('Guardar anim'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickAndUpload(animated: true),
                    icon: const Icon(Icons.gif_box_outlined),
                    label: const Text('Galería'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
