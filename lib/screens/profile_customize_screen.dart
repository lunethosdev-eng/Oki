import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pokke/services/settings_service.dart';
import 'package:pokke/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileCustomizeScreen extends StatefulWidget {
  const ProfileCustomizeScreen({super.key});
  @override
  State<ProfileCustomizeScreen> createState() => _ProfileCustomizeScreenState();
}

class _ProfileCustomizeScreenState extends State<ProfileCustomizeScreen> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  String _theme = 'default';
  String _frame = 'none';
  final _stickers = <Offset>[];
  String? _avatarPath;
  String? _bannerPath;
  String? _avatarUrl;
  String? _bannerUrl;
  bool _saving = false;
  final _picker = ImagePicker();

  static const _stickerEmojis = ['🎵', '✨', '🔥', '💜', '🎧', '🌙', '⭐'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final local = await SharedPreferences.getInstance();
    _avatarPath = local.getString('profile_avatar_path');
    _bannerPath = local.getString('profile_banner_path');
    final p = await SupabaseService.getProfile();
    if (p != null && mounted) {
      _name.text = p['display_name']?.toString() ?? '';
      _bio.text = p['bio']?.toString() ?? '';
      setState(() {
        _theme = p['theme']?.toString() ?? 'default';
        _frame = p['frame']?.toString() ?? 'none';
        _avatarUrl = p['avatar_url']?.toString();
        _bannerUrl = p['banner_url']?.toString();
      });
    } else if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final x = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1024, imageQuality: 85);
    if (x == null) return;
    setState(() {
      _avatarPath = x.path;
      _avatarUrl = null;
    });
    final p = await SharedPreferences.getInstance();
    await p.setString('profile_avatar_path', x.path);
  }

  Future<void> _pickBanner() async {
    final x = await _picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (x == null) return;
    setState(() {
      _bannerPath = x.path;
      _bannerUrl = null;
    });
    final p = await SharedPreferences.getInstance();
    await p.setString('profile_banner_path', x.path);
  }

  Future<String?> _upload(String path, String folder) async {
    if (!SupabaseService.isLoggedIn || SupabaseService.isGuest) return null;
    try {
      final uid = SupabaseService.currentUser!.id;
      final bytes = await File(path).readAsBytes();
      final name = '$folder/$uid/${DateTime.now().millisecondsSinceEpoch}.jpg';
      await SupabaseService.kokoro.storage.from('avatars').uploadBinary(
            name,
            bytes,
          );
      return SupabaseService.kokoro.storage.from('avatars').getPublicUrl(name);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      String? av = _avatarUrl;
      String? bn = _bannerUrl;
      if (_avatarPath != null) {
        av = await _upload(_avatarPath!, 'avatar') ?? av;
      }
      if (_bannerPath != null) {
        bn = await _upload(_bannerPath!, 'banner') ?? bn;
      }
      if (!SupabaseService.isGuest && SupabaseService.isLoggedIn) {
        await SupabaseService.updateProfile({
          'display_name': _name.text.trim(),
          'bio': _bio.text.trim(),
          'theme': _theme,
          'frame': _frame,
          if (av != null) 'avatar_url': av,
          if (bn != null) 'banner_url': bn,
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil guardado')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _avatarPreview() {
    if (_avatarPath != null) {
      return Image.file(File(_avatarPath!), fit: BoxFit.cover);
    }
    if (_avatarUrl != null && _avatarUrl!.startsWith('http')) {
      return Image.network(_avatarUrl!, fit: BoxFit.cover);
    }
    return const Icon(Icons.person, size: 48);
  }

  Widget _bannerPreview() {
    if (_bannerPath != null) {
      return Image.file(File(_bannerPath!), fit: BoxFit.cover);
    }
    if (_bannerUrl != null && _bannerUrl!.startsWith('http')) {
      return Image.network(_bannerUrl!, fit: BoxFit.cover);
    }
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.image_outlined, size: 40)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Personalizar perfil'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Guardar'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          GestureDetector(
            onTap: _pickBanner,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(height: 140, width: double.infinity, child: _bannerPreview()),
            ),
          ),
          const SizedBox(height: 8),
          Text('Toca el banner para cambiarlo',
              style: TextStyle(fontSize: 12, color: cs.onSurface.withOpacity(0.45))),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: _pickAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: cs.surfaceContainerHighest,
                    child: ClipOval(
                      child: SizedBox(
                          width: 96, height: 96, child: _avatarPreview()),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: cs.primary,
                      child: Icon(Icons.camera_alt,
                          size: 16, color: cs.onPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bio,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Bio',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Text('Tema', style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final t in ['default', 'neon', 'minimal', 'sunset'])
                ChoiceChip(
                  label: Text(t),
                  selected: _theme == t,
                  onSelected: (_) => setState(() => _theme = t),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Marco', style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final f in ['none', 'gold', 'glass', 'owner'])
                ChoiceChip(
                  label: Text(f),
                  selected: _frame == f,
                  onSelected: (_) => setState(() => _frame = f),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Stickers (tap para colocar)',
              style: TextStyle(fontWeight: FontWeight.w700, color: cs.onSurface)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final e in _stickerEmojis)
                ActionChip(
                  label: Text(e, style: const TextStyle(fontSize: 20)),
                  onPressed: () => setState(
                      () => _stickers.add(Offset(
                          40.0 + _stickers.length * 12, 40.0))),
                ),
            ],
          ),
          if (_stickers.isNotEmpty)
            SizedBox(
              height: 120,
              child: Stack(
                children: [
                  for (var i = 0; i < _stickers.length; i++)
                    Positioned(
                      left: _stickers[i].dx,
                      top: _stickers[i].dy,
                      child: Text(_stickerEmojis[i % _stickerEmojis.length],
                          style: const TextStyle(fontSize: 28)),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
