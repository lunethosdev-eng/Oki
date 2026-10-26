import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pokke/services/player_controller.dart';
import 'package:pokke/services/devices_service.dart';
import 'package:pokke/services/device_link_service.dart';
import 'package:pokke/services/voice_search_service.dart';
import 'package:pokke/services/music_api_service.dart';
import 'package:pokke/services/supabase_service.dart';

/// Virtual remote. Voice uses the **phone microphone**.
class RemoteControlScreen extends StatefulWidget {
  const RemoteControlScreen({super.key});
  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  double _vol = 0.8;
  bool _listening = false;
  String? _lastHeard;
  String? _status;

  @override
  void initState() {
    super.initState();
    DevicesService.instance.refresh();
    _vol = PlayerController.instance.volume.clamp(0.0, 1.0);
    VoiceSearchService.instance.init();
  }

  void _cmd(String name, VoidCallback action) {
    HapticFeedback.lightImpact();
    action();
    setState(() => _status = name);
  }

  /// Parse spoken command (ES / EN) and execute.
  Future<void> _handleVoiceText(String raw) async {
    final t = raw.toLowerCase().trim();
    setState(() {
      _lastHeard = raw;
      _status = 'Oí: $raw';
    });
    final pc = PlayerController.instance;

    // Transport
    if (_match(t, [
      'play', 'reproduce', 'reproducir', 'continua', 'continuar', 'resume',
      'dale play', 'pon play'
    ])) {
      _cmd('Play', () => pc.resume());
      return;
    }
    if (_match(t, [
      'pause', 'pausa', 'pausar', 'para', 'detener', 'stop', 'detén'
    ])) {
      _cmd('Pausa', () => pc.pause());
      return;
    }
    if (_match(t, [
      'siguiente', 'next', 'adelante', 'otra canción', 'skip'
    ])) {
      _cmd('Siguiente', () => pc.next());
      return;
    }
    if (_match(t, [
      'anterior', 'previous', 'atrás', 'atras', 'la de antes'
    ])) {
      _cmd('Anterior', () => pc.previous());
      return;
    }
    if (_match(t, ['mute', 'silencio', 'calla', 'sin volumen'])) {
      _cmd('Mute', () {
        pc.setVolume(0);
        setState(() => _vol = 0);
      });
      return;
    }
    if (_match(t, [
      'sube el volumen', 'más volumen', 'volume up', 'sube volumen', 'más alto'
    ])) {
      final v = (_vol + 0.15).clamp(0.0, 1.0);
      _cmd('Vol +', () {
        pc.setVolume(v);
        setState(() => _vol = v);
      });
      return;
    }
    if (_match(t, [
      'baja el volumen', 'menos volumen', 'volume down', 'baja volumen', 'más bajo'
    ])) {
      final v = (_vol - 0.15).clamp(0.0, 1.0);
      _cmd('Vol −', () {
        pc.setVolume(v);
        setState(() => _vol = v);
      });
      return;
    }

    // "pon / reproduce / play [song]"
    String? query;
    for (final prefix in [
      'reproduce ',
      'pon la canción ',
      'pon canción ',
      'pon ',
      'play ',
      'busca ',
      'buscar ',
      'quiero oír ',
      'quiero escuchar ',
      'escucha ',
    ]) {
      if (t.startsWith(prefix)) {
        query = t.substring(prefix.length).trim();
        break;
      }
    }
    // bare query fallback if long enough
    if ((query == null || query.isEmpty) && t.split(' ').length >= 2) {
      query = t;
    }
    if (query != null && query.isNotEmpty) {
      setState(() => _status = 'Buscando “$query”…');
      await _playQuery(query);
      return;
    }

    setState(() => _status = 'No entendí. Prueba: “siguiente”, “pausa”, “pon unhappy”');
  }

  bool _match(String t, List<String> keys) {
    for (final k in keys) {
      if (t == k || t.contains(k)) return true;
    }
    return false;
  }

  Future<void> _playQuery(String q) async {
    try {
      List<Map<String, dynamic>> hits = [];
      try {
        hits = await MusicApiService.search(q);
      } catch (_) {}
      if (hits.isEmpty) {
        final all = await SupabaseService.getSongs(limit: 80);
        final ql = q.toLowerCase();
        hits = all.where((s) {
          final title = (s['title'] ?? '').toString().toLowerCase();
          final artist = (s['artist'] ?? '').toString().toLowerCase();
          return title.contains(ql) || artist.contains(ql) || ql.contains(title);
        }).toList();
      }
      if (hits.isEmpty) {
        setState(() => _status = 'No encontré “$q”');
        return;
      }
      final song = hits.first;
      await PlayerController.instance.play(song, asQueue: hits, index: 0);
      setState(() {
        _status =
            '♪ ${song['title'] ?? q} — ${song['artist'] ?? ''}';
      });
    } catch (e) {
      setState(() => _status = 'Error: $e');
    }
  }

  Future<void> _listen() async {
    if (_listening) {
      await VoiceSearchService.instance.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() {
      _listening = true;
      _status = 'Escuchando (mic del teléfono)…';
    });
    HapticFeedback.mediumImpact();
    final text = await VoiceSearchService.instance.listenOnce(
      timeout: const Duration(seconds: 7),
    );
    if (!mounted) return;
    setState(() => _listening = false);
    if (text == null || text.isEmpty) {
      setState(() => _status = 'No escuché nada. Revisa permiso de micrófono.');
      return;
    }
    await _handleVoiceText(text);
  }

  Widget _pad(IconData icon, String label, VoidCallback onTap,
      {double size = 56, Color? color}) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: color ?? Colors.white10,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _cmd(label, onTap),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white, size: size * 0.42),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final linked = DeviceLinkService.instance.linked;
    final pc = PlayerController.instance;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0B0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Text('Control remoto'),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([pc, DevicesService.instance]),
        builder: (_, __) {
          final song = pc.current;
          final title = song?['title']?.toString() ?? 'Nada en reproducción';
          final artist = song?['artist']?.toString() ?? '';
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              children: [
                Text(
                  linked
                      ? 'TV vinculada · el mic es del teléfono'
                      : 'Mic del teléfono · controla la reproducción',
                  style: TextStyle(color: Colors.white.withOpacity(0.55)),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                Text(artist,
                    style: TextStyle(color: Colors.white.withOpacity(0.5))),
                if (_status != null) ...[
                  const SizedBox(height: 10),
                  Text(_status!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: _listening
                              ? Colors.lightBlueAccent
                              : Colors.white70,
                          fontSize: 13)),
                ],
                if (_lastHeard != null)
                  Text('“$_lastHeard”',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          fontSize: 12)),
                const Spacer(),
                // Big mic button
                GestureDetector(
                  onTap: _listen,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _listening
                          ? Colors.redAccent.withOpacity(0.9)
                          : Colors.lightBlueAccent.withOpacity(0.85),
                      boxShadow: [
                        BoxShadow(
                          color: (_listening
                                  ? Colors.redAccent
                                  : Colors.lightBlueAccent)
                              .withOpacity(0.45),
                          blurRadius: _listening ? 28 : 16,
                        ),
                      ],
                    ),
                    child: Icon(
                      _listening ? Icons.mic : Icons.mic_none,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _listening
                      ? 'Escuchando… toca para parar'
                      : 'Toca el mic · “siguiente”, “pausa”, “pon unhappy”',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 12),
                ),
                const SizedBox(height: 24),
                // Transport
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _pad(Icons.skip_previous, 'Anterior', () => pc.previous()),
                    _pad(
                      pc.playing ? Icons.pause : Icons.play_arrow,
                      pc.playing ? 'Pausa' : 'Play',
                      () => pc.playing ? pc.pause() : pc.resume(),
                      size: 72,
                      color: Colors.white24,
                    ),
                    _pad(Icons.skip_next, 'Siguiente', () => pc.next()),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Icon(Icons.volume_down, color: Colors.white70),
                    Expanded(
                      child: Slider(
                        value: _vol,
                        onChanged: (v) {
                          setState(() => _vol = v);
                          pc.setVolume(v);
                        },
                      ),
                    ),
                    const Icon(Icons.volume_up, color: Colors.white70),
                  ],
                ),
                const Spacer(),
              ],
            ),
          );
        },
      ),
    );
  }
}
