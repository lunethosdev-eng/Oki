import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pokke/services/player_controller.dart';
import 'package:pokke/services/devices_service.dart';
import 'package:pokke/services/device_link_service.dart';

/// Virtual remote when a TV / linked device is available.
class RemoteControlScreen extends StatefulWidget {
  const RemoteControlScreen({super.key});
  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  double _vol = 0.8;

  @override
  void initState() {
    super.initState();
    DevicesService.instance.refresh();
    _vol = PlayerController.instance.volume.clamp(0.0, 1.0);
  }

  void _cmd(String name, VoidCallback action) {
    HapticFeedback.lightImpact();
    action();
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(name),
        duration: const Duration(milliseconds: 600),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _pad(IconData icon, String label, VoidCallback onTap,
      {double size = 56}) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.white10,
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
                      ? 'TV / dispositivo vinculado'
                      : 'Sin TV vinculada · controla este dispositivo',
                  style: TextStyle(color: Colors.white.withOpacity(0.55)),
                ),
                const SizedBox(height: 16),
                Text(title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800)),
                Text(artist,
                    style: TextStyle(color: Colors.white.withOpacity(0.5))),
                const Spacer(),
                // D-pad style
                Column(
                  children: [
                    _pad(Icons.keyboard_arrow_up, 'Arriba', () {}),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _pad(Icons.keyboard_arrow_left, 'Izquierda', () {}),
                        const SizedBox(width: 12),
                        _pad(Icons.circle, 'OK', () {}, size: 64),
                        const SizedBox(width: 12),
                        _pad(Icons.keyboard_arrow_right, 'Derecha', () {}),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _pad(Icons.keyboard_arrow_down, 'Abajo', () {}),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _pad(Icons.skip_previous, 'Anterior', () => pc.previous()),
                    _pad(
                      pc.playing ? Icons.pause : Icons.play_arrow,
                      pc.playing ? 'Pausa' : 'Play',
                      () => pc.playing ? pc.pause() : pc.resume(),
                      size: 72,
                    ),
                    _pad(Icons.skip_next, 'Siguiente', () => pc.next()),
                  ],
                ),
                const SizedBox(height: 24),
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
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      onPressed: () => _cmd('Mute', () {
                        pc.setVolume(_vol > 0 ? 0 : 0.8);
                        setState(() => _vol = _vol > 0 ? 0 : 0.8);
                      }),
                      icon: const Icon(Icons.volume_off),
                      label: const Text('Mute'),
                    ),
                    TextButton.icon(
                      onPressed: () => _cmd('Letras', () {}),
                      icon: const Icon(Icons.lyrics_outlined),
                      label: const Text('Letras'),
                    ),
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
