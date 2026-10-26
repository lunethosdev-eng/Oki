import 'package:pokke/services/devices_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:pokke/services/settings_service.dart';
import 'package:pokke/services/music_api_service.dart';
import 'package:pokke/services/supabase_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:pokke/screens/listen_together_screen.dart';
import 'package:pokke/screens/friends_map_screen.dart';
import 'package:pokke/screens/chat_list_screen.dart';
import 'package:pokke/screens/device_link_screen.dart';
import 'package:pokke/screens/remote_control_screen.dart';
import 'package:pokke/screens/owner_panel_screen.dart';
import 'package:pokke/services/offline_service.dart';
import 'package:pokke/adaptive/breakpoints.dart';

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
              
              
              _h('Héroe Home (TV)'),
              ListTile(
                title: const Text('Media del héroe'),
                subtitle: Text(
                  s.heroMediaPath == null || s.heroMediaPath!.isEmpty
                      ? 'Cover de la primera canción por defecto'
                      : s.heroMediaPath!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () async {
                        final x = await ImagePicker().pickImage(
                            source: ImageSource.gallery);
                        if (x != null) {
                          await s.setHeroMedia(x.path, type: 'image');
                        }
                      },
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Imagen/GIF'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final x = await ImagePicker().pickVideo(
                            source: ImageSource.gallery);
                        if (x != null) {
                          await s.setHeroMedia(x.path, type: 'video');
                        }
                      },
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('MP4'),
                    ),
                    TextButton(
                      onPressed: () => s.setHeroMedia(null),
                      child: const Text('Quitar'),
                    ),
                  ],
                ),
              ),

              Text('Tamaño del héroe',
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.55))),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'small', label: Text('Chico')),
                  ButtonSegment(value: 'medium', label: Text('Medio')),
                  ButtonSegment(value: 'large', label: Text('Grande')),
                ],
                selected: {s.heroSize},
                onSelectionChanged: (v) => s.setHeroSize(v.first),
              ),
              const SizedBox(height: 10),
              Text('Estilo del héroe',
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.55))),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in const [
                    ('cover', 'Cover'),
                    ('video', 'Video'),
                    ('gradient', 'Degradado'),
                    ('cinematic', 'Cine'),
                  ])
                    ChoiceChip(
                      label: Text(m.$2),
                      selected: s.heroStyle == m.$1,
                      onSelected: (_) => s.setHeroStyle(m.$1),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _h('Player'),
              ListTile(
                title: const Text('Fondo del player'),
                subtitle: Text(_bgLabel(s.playerBgMode)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final m in const [
                      ('color', 'Colores', Icons.palette_outlined),
                      ('blur', 'Blur', Icons.blur_on),
                      ('cinematic', 'Cine', Icons.movie_filter_outlined),
                      ('dark', 'Oscuro', Icons.dark_mode_outlined),
                      ('gradient', 'Degradado', Icons.gradient),
                      ('mesh', 'Mesh', Icons.bubble_chart_outlined),
                    ])
                      ChoiceChip(
                        avatar: Icon(m.$3, size: 16),
                        label: Text(m.$2),
                        selected: s.playerBgMode == m.$1,
                        onSelected: (_) => s.setPlayerBgMode(m.$1),
                      ),
                  ],
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
              
              
              
              
              _h('Letras'),
              Text('Modo de animación',
                  style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.55))),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'normal', label: Text('Normal')),
                  ButtonSegment(value: 'color', label: Text('Colorear')),
                  ButtonSegment(value: 'emotion', label: Text('Emoción')),
                ],
                selected: {s.lyricsMode},
                onSelectionChanged: (v) => s.setLyricsMode(v.first),
              ),
              const SizedBox(height: 6),
              Text(
                s.lyricsMode == 'normal'
                    ? 'Línea activa sin colorear letra por letra'
                    : s.lyricsMode == 'color'
                        ? 'Karaoke letra por letra sincronizado'
                        : 'Palabras intensas en rojo + glow del fondo',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.45)),
              ),
              const SizedBox(height: 16),
              _h('Dispositivos'),
              ListTile(
                leading: const Icon(Icons.cloud_download_outlined),
                title: const Text('Descargar catálogo offline'),
                subtitle: AnimatedBuilder(
                  animation: OfflineService.instance,
                  builder: (_, __) {
                    final o = OfflineService.instance;
                    if (o.downloadingCatalog) {
                      return Text(
                          '${o.catalogDone}/${o.catalogTotal} · ETA ${o.etaLabel()}');
                    }
                    return const Text('Segundo plano · Music/Pokke');
                  },
                ),
                onTap: () async {
                  final go = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Descarga offline'),
                      content: const Text(
                          'Descarga el catálogo dentro de la app (Music/Pokke). Puede tardar según la red.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancelar')),
                        FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Descargar')),
                      ],
                    ),
                  );
                  if (go == true) OfflineService.instance.downloadCatalog();
                },
              ),
              ListTile(
                leading: const Icon(Icons.cast_connected_outlined),
                title: const Text('Vincular dispositivo'),
                subtitle: const Text('QR / código para TV o otra pantalla'),
                onTap: () {
                  final isTv =
                      Breakpoints.of(context) == PokkeFormFactor.tv;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeviceLinkScreen(asTvHost: isTv),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_remote_outlined),
                title: const Text('Control remoto'),
                subtitle: const Text('Mando virtual si hay TV vinculada'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const RemoteControlScreen()),
                  );
                },
              ),
              const SizedBox(height: 8),
              Text('Sesiones / dispositivos',
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).colorScheme.onSurface)),
              AnimatedBuilder(
                animation: DevicesService.instance,
                builder: (_, __) {
                  final devs = DevicesService.instance.devices;
                  if (devs.isEmpty) {
                    return ListTile(
                      dense: true,
                      title: Text('Ninguno detectado',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.45))),
                      trailing: IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () =>
                            DevicesService.instance.refresh(),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      for (final d in devs)
                        ListTile(
                          leading: Icon(
                              DevicesService.instance.iconFor(d.type)),
                          title: Text(d.name),
                          subtitle: Text(
                            '${d.type}'
                            '${d.battery != null ? ' · ${d.battery}%' : ''}'
                            '${d.active ? ' · activo' : ''}',
                          ),
                        ),
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text(
                            'Cerrar sesión en este dispositivo'),
                        onTap: () async {
                          await SupabaseService.signOut();
                          if (context.mounted) {
                            Navigator.of(context)
                                .popUntil((r) => r.isFirst);
                          }
                        },
                      ),
                    ],
                  );
                },
              ),
              if (SupabaseService.isOwner)
                ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined),
                  title: const Text('Owner panel'),
                  subtitle: const Text('Servidor, covers, catálogo'),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const OwnerPanelScreen()),
                  ),
                ),
              const SizedBox(height: 8),
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
                    MaterialPageRoute(builder: (_) => const ChatListScreen()),
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

  String _bgLabel(String m) => switch (m) {
        'blur' => 'Blur del cover',
        'cinematic' => 'Cinemático · vignette + drift',
        'dark' => 'Oscuro / AMOLED',
        'gradient' => 'Degradado del cover',
        'mesh' => 'Mesh de colores del cover',
        _ => 'Colores del cover',
      };

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
