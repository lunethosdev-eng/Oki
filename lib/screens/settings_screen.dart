import 'package:flutter/material.dart';
import 'package:pokke/services/settings_service.dart';
import 'package:pokke/services/music_api_service.dart';
import 'package:pokke/services/supabase_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:pokke/screens/listen_together_screen.dart';
import 'package:pokke/screens/friends_map_screen.dart';
import 'package:pokke/screens/private_chat_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _sfx = AudioPlayer();
  final _serverCtrl = TextEditingController();

  static const _sounds = {
    'message': 'sounds/tone_message.mp3',
    'joyous': 'sounds/tone_joyous.mp3',
    'bubble': 'sounds/tone_bubble.mp3',
    'twinkle': 'sounds/tone_twinkle.mp3',
    'marimba': 'sounds/tone_marimba.mp3',
    'chime': 'sounds/tone_chime.mp3',
  };

  @override
  void initState() {
    super.initState();
    _serverCtrl.text = SettingsService.instance.musicApiBaseOverride ?? '';
  }

  @override
  void dispose() {
    _sfx.dispose();
    _serverCtrl.dispose();
    super.dispose();
  }

  Future<void> _preview(String id) async {
    final path = _sounds[id];
    if (path == null) return;
    try {
      await _sfx.stop();
      await _sfx.play(AssetSource(path));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final s = SettingsService.instance;
    return AnimatedBuilder(
      animation: s,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Settings')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              _h('Apariencia'),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.system, label: Text('Sistema')),
                  ButtonSegment(
                      value: ThemeMode.light, label: Text('Claro')),
                  ButtonSegment(
                      value: ThemeMode.dark, label: Text('Oscuro')),
                ],
                selected: {s.themeMode},
                onSelectionChanged: (v) => s.setThemeMode(v.first),
              ),
              const SizedBox(height: 20),
              _h('Liquid Glass (experimental)'),
              SwitchListTile(
                title: const Text('Activar Liquid Glass'),
                subtitle:
                    const Text('Off por defecto · mejora animaciones'),
                value: s.liquidGlassEnabled,
                onChanged: s.setLiquidGlassEnabled,
              ),
              if (s.liquidGlassEnabled) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final m in ['system', 'custom', 'mono'])
                      ChoiceChip(
                        label: Text({
                          'system': 'Sistema',
                          'custom': 'Custom',
                          'mono': 'Mono',
                        }[m]!),
                        selected: s.liquidGlassColorMode == m,
                        onSelected: (_) => s.setLiquidGlassColorMode(m),
                      ),
                  ],
                ),
                ListTile(
                  title: Text(
                      'Opacidad ${(s.liquidGlassOpacity * 100).round()}%'),
                ),
                Slider(
                  value: s.liquidGlassOpacity,
                  min: 0.05,
                  max: 0.45,
                  onChanged: s.setLiquidGlassOpacity,
                ),
                ListTile(title: Text('Blur ${s.liquidGlassBlur.round()}')),
                Slider(
                  value: s.liquidGlassBlur,
                  min: 4,
                  max: 36,
                  onChanged: s.setLiquidGlassBlur,
                ),
              ],
              const SizedBox(height: 12),
              _h('Búsqueda'),
              SwitchListTile(
                title: const Text('Guardar historial de búsqueda'),
                value: s.saveSearchHistory,
                onChanged: s.setSaveSearchHistory,
              ),
              const SizedBox(height: 12),
              _h('Notificaciones · sonidos'),
              SwitchListTile(
                title: const Text('Sonido de notificación'),
                value: s.notificationSoundEnabled,
                onChanged: s.setNotificationSoundEnabled,
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final id in _sounds.keys)
                    ActionChip(
                      label: Text(id),
                      onPressed: () {
                        s.notificationSound = id;
                        _preview(id);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              _h('Beta · funciones reales'),
              
              _h('Player'),
              ListTile(
                title: const Text('Fondo del player'),
                subtitle: Text(s.playerBgMode == 'blur' ? 'Blur del cover' : 'Colores del cover'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'color', label: Text('Colores'), icon: Icon(Icons.palette_outlined)),
                    ButtonSegment(value: 'blur', label: Text('Blur'), icon: Icon(Icons.blur_on)),
                  ],
                  selected: {s.playerBgMode},
                  onSelectionChanged: (v) => s.setPlayerBgMode(v.first),
                ),
              ),
              const SizedBox(height: 16),
              for (final e in s.beta.entries)
                SwitchListTile(
                  title: Text(_betaLabel(e.key)),
                  subtitle: Text(_betaSub(e.key)),
                  value: e.value,
                  onChanged: (v) => s.setBeta(e.key, v),
                ),
              
              
              if (s.flag('friends_map'))
                ListTile(
                  leading: const Icon(Icons.map_outlined),
                  title: const Text('Abrir mapa de amigos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FriendsMapScreen()),
                  ),
                ),
              if (s.flag('private_chat'))
                ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: const Text('Abrir chat privado'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PrivateChatScreen()),
                  ),
                ),

              if (s.flag('listen_together'))
                ListTile(
                  leading: const Icon(Icons.headphones),
                  title: const Text('Abrir Listen together'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ListenTogetherScreen()),
                  ),
                ),

              if (SupabaseService.isOwner) ...[
                const SizedBox(height: 20),
                _h('Owner'),
                TextField(
                  controller: _serverCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Music API base URL (Ukiyo)',
                    border: OutlineInputBorder(),
                    hintText: 'https://…',
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () async {
                    await MusicApiService.setGlobalBase(_serverCtrl.text);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Servidor guardado')),
                      );
                    }
                  },
                  child: const Text('Guardar servidor'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  String _betaLabel(String k) => {
        'listen_together': 'Listen together',
        'friends_map': 'Mapa de amigos (3D)',
        'private_chat': 'Chat privado',
        'karaoke_ai': 'Karaoke AI sync',
        'dual_session': 'Sesión dual / audífonos',
      }[k] ??
      k;

  String _betaSub(String k) => {
        'listen_together': 'Salas con código, misma cola',
        'friends_map': 'Ubicación, batería, stats en tiempo real',
        'private_chat': 'Mensajes, reacciones, racha, media',
        'karaoke_ai': 'Timing de letras adaptativo',
        'dual_session': 'Dos pares en la misma sesión',
      }[k] ??
      '';

  Widget _h(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: Text(t,
            style:
                const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      );
}
