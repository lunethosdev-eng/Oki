import 'package:flutter/material.dart';
import 'package:pokke/services/settings_service.dart';
import 'package:pokke/services/supabase_service.dart';

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
  bool _saving = false;

  static const _stickerEmojis = ['🎵', '✨', '🔥', '💜', '🎧', '🌙', '⭐'];

  @override
  void initState() {
    super.initState();
    SupabaseService.getProfile().then((p) {
      if (p == null || !mounted) return;
      _name.text = p['display_name']?.toString() ?? '';
      _bio.text = p['bio']?.toString() ?? '';
      setState(() {
        _theme = p['theme']?.toString() ?? 'default';
        _frame = p['frame']?.toString() ?? 'none';
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (!SupabaseService.isGuest && SupabaseService.isLoggedIn) {
        await SupabaseService.updateProfile({
          'display_name': _name.text.trim(),
          'bio': _bio.text.trim(),
          'theme': _theme,
          'frame': _frame,
        });
      }
      // local prefs always
      final s = SettingsService.instance;
      await s.setThemeMode(s.themeMode); // touch notify
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
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          // Banner placeholder
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
              gradient: _theme == 'aurora'
                  ? LinearGradient(colors: [
                      cs.primary.withOpacity(0.4),
                      cs.tertiary.withOpacity(0.3)
                    ])
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(
              'Banner (GIF / imagen — próximamente picker)',
              style: TextStyle(color: cs.onSurface.withOpacity(0.45), fontSize: 12),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: _frame == 'none'
                    ? null
                    : Border.all(
                        color: _frame == 'neon' ? cs.primary : cs.outline,
                        width: _frame == 'neon' ? 3 : 2),
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: cs.surfaceContainerHighest,
                child: Icon(Icons.person, size: 40, color: cs.onSurface.withOpacity(0.4)),
              ),
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nombre / Nickname',
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
          const SizedBox(height: 20),
          const Text('Theme', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final t in ['default', 'aurora', 'mono', 'warm'])
                ChoiceChip(
                  label: Text(t),
                  selected: _theme == t,
                  onSelected: (_) => setState(() => _theme = t),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Marco avatar', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final f in ['none', 'ring', 'neon', 'soft'])
                ChoiceChip(
                  label: Text(f),
                  selected: _frame == f,
                  onSelected: (_) => setState(() => _frame = f),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Stickers (toca para colocar)',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final e in _stickerEmojis)
                ActionChip(
                  label: Text(e, style: const TextStyle(fontSize: 20)),
                  onPressed: () => setState(() {
                    _stickers.add(Offset(
                      40.0 + _stickers.length * 12,
                      20.0 + (_stickers.length % 3) * 10,
                    ));
                  }),
                ),
            ],
          ),
          if (_stickers.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 80,
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
          if (SupabaseService.isGuest)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Invitado: la personalización se guarda solo en este dispositivo. Crea cuenta para sincronizar con Kokoro.',
                style: TextStyle(color: cs.onSurface.withOpacity(0.45), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
