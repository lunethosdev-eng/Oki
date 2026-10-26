import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pokke/services/player_controller.dart';
import 'package:pokke/services/devices_service.dart';
import 'package:pokke/services/device_link_service.dart';
import 'package:pokke/services/voice_search_service.dart';
import 'package:pokke/services/music_api_service.dart';
import 'package:pokke/services/supabase_service.dart';

/// Virtual remote shaped like a Google TV / Android TV remote.
/// Voice always uses the **phone microphone**.
class RemoteControlScreen extends StatefulWidget {
  const RemoteControlScreen({super.key});
  @override
  State<RemoteControlScreen> createState() => _RemoteControlScreenState();
}

class _RemoteControlScreenState extends State<RemoteControlScreen> {
  double _vol = 0.8;
  bool _listening = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    DevicesService.instance.refresh();
    _vol = PlayerController.instance.volume.clamp(0.0, 1.0);
    VoiceSearchService.instance.init();
  }

  void _haptic() => HapticFeedback.lightImpact();

  Widget _round(IconData icon, VoidCallback onTap,
      {double size = 48, Color bg = const Color(0xFF2A2A2E), String? tip}) {
    return Tooltip(
      message: tip ?? '',
      child: Material(
        color: bg,
        shape: const CircleBorder(),
        elevation: 2,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            _haptic();
            onTap();
          },
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white, size: size * 0.42),
          ),
        ),
      ),
    );
  }

  Future<void> _listen() async {
    if (_listening) {
      await VoiceSearchService.instance.stop();
      setState(() => _listening = false);
      return;
    }
    setState(() {
      _listening = true;
      _status = 'Escuchando…';
    });
    final text = await VoiceSearchService.instance
        .listenOnce(timeout: const Duration(seconds: 7));
    if (!mounted) return;
    setState(() => _listening = false);
    if (text == null || text.isEmpty) {
      setState(() => _status = 'Sin audio — revisa el micrófono');
      return;
    }
    await _handleVoice(text);
  }

  Future<void> _handleVoice(String raw) async {
    final t = raw.toLowerCase().trim();
    setState(() => _status = '“$raw”');
    final pc = PlayerController.instance;
    if (RegExp(r'play|reproduce|continua').hasMatch(t)) {
      await pc.resume();
      return;
    }
    if (RegExp(r'pausa|pause|stop|para').hasMatch(t)) {
      await pc.pause();
      return;
    }
    if (RegExp(r'siguiente|next|skip').hasMatch(t)) {
      await pc.next();
      return;
    }
    if (RegExp(r'anterior|previous|atr[aá]s').hasMatch(t)) {
      await pc.previous();
      return;
    }
    // search
    var q = t;
    for (final p in ['pon ', 'reproduce ', 'busca ', 'play ']) {
      if (t.startsWith(p)) {
        q = t.substring(p.length);
        break;
      }
    }
    setState(() => _status = 'Buscando $q…');
    try {
      var hits = <Map<String, dynamic>>[];
      try {
        hits = await MusicApiService.search(q);
      } catch (_) {}
      if (hits.isEmpty) {
        final all = await SupabaseService.getSongs(limit: 80);
        final ql = q.toLowerCase();
        hits = all
            .where((s) =>
                '${s['title']}'.toLowerCase().contains(ql) ||
                '${s['artist']}'.toLowerCase().contains(ql))
            .toList();
      }
      if (hits.isEmpty) {
        setState(() => _status = 'No encontré $q');
        return;
      }
      await PlayerController.instance.play(hits.first, asQueue: hits, index: 0);
      setState(() => _status = '♪ ${hits.first['title']}');
    } catch (e) {
      setState(() => _status = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final pc = PlayerController.instance;
    final linked = DeviceLinkService.instance.linked;

    return Scaffold(
      backgroundColor: const Color(0xFF121214),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Control remoto'),
            Text(
              linked ? 'TV vinculada' : 'Este teléfono · mic local',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: pc,
        builder: (_, __) {
          final song = pc.current;
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 280,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1F),
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Now playing
                    Text(
                      song?['title']?.toString() ?? 'Pokke Remote',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                    Text(
                      song?['artist']?.toString() ??
                          'Mic del teléfono · comandos de voz',
                      maxLines: 1,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.45), fontSize: 11),
                    ),
                    if (_status != null) ...[
                      const SizedBox(height: 6),
                      Text(_status!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: _listening
                                  ? Colors.redAccent
                                  : Colors.lightBlueAccent,
                              fontSize: 11)),
                    ],
                    const SizedBox(height: 18),
                    // Power / mute row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _round(Icons.power_settings_new, () => pc.pause(),
                            size: 44,
                            bg: const Color(0xFF3A1515),
                            tip: 'Stop'),
                        _round(
                          Icons.volume_off,
                          () {
                            final v = _vol > 0 ? 0.0 : 0.8;
                            setState(() => _vol = v);
                            pc.setVolume(v);
                          },
                          size: 44,
                          tip: 'Mute',
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Assistant / voice / settings
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _round(Icons.person_outline, () {}, size: 42),
                        GestureDetector(
                          onTap: _listen,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: _listening
                                    ? [Colors.redAccent, Colors.orange]
                                    : [
                                        const Color(0xFF4285F4),
                                        const Color(0xFF34A853),
                                        const Color(0xFFFBBC05),
                                        const Color(0xFFEA4335),
                                      ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_listening
                                          ? Colors.redAccent
                                          : const Color(0xFF4285F4))
                                      .withOpacity(0.45),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: Icon(
                              _listening ? Icons.mic : Icons.mic_none,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        _round(Icons.settings_outlined, () {}, size: 42),
                      ],
                    ),
                    const SizedBox(height: 22),
                    // D-pad ring
                    SizedBox(
                      width: 168,
                      height: 168,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF2A2A2E),
                            ),
                          ),
                          // directions
                          Positioned(
                            top: 8,
                            child: IconButton(
                              onPressed: () => _haptic(),
                              icon: const Icon(Icons.keyboard_arrow_up,
                                  color: Colors.white70, size: 32),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            child: IconButton(
                              onPressed: () => _haptic(),
                              icon: const Icon(Icons.keyboard_arrow_down,
                                  color: Colors.white70, size: 32),
                            ),
                          ),
                          Positioned(
                            left: 8,
                            child: IconButton(
                              onPressed: () {
                                _haptic();
                                pc.previous();
                              },
                              icon: const Icon(Icons.keyboard_arrow_left,
                                  color: Colors.white70, size: 32),
                            ),
                          ),
                          Positioned(
                            right: 8,
                            child: IconButton(
                              onPressed: () {
                                _haptic();
                                pc.next();
                              },
                              icon: const Icon(Icons.keyboard_arrow_right,
                                  color: Colors.white70, size: 32),
                            ),
                          ),
                          // OK / play-pause
                          Material(
                            color: const Color(0xFF3A3A40),
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: () {
                                _haptic();
                                pc.playing ? pc.pause() : pc.resume();
                              },
                              child: SizedBox(
                                width: 64,
                                height: 64,
                                child: Icon(
                                  pc.playing ? Icons.pause : Icons.play_arrow,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Back / home / menu
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _round(Icons.arrow_back, () => Navigator.maybePop(context),
                            size: 46, tip: 'Atrás'),
                        _round(Icons.home_outlined, () {
                          Navigator.of(context)
                              .popUntil((r) => r.isFirst);
                        }, size: 46, tip: 'Home'),
                        _round(Icons.menu, () {}, size: 46, tip: 'Menú'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Volume
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _round(Icons.remove, () {
                          final v = (_vol - 0.1).clamp(0.0, 1.0);
                          setState(() => _vol = v);
                          pc.setVolume(v);
                        }, size: 44, tip: 'Vol −'),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text('${(_vol * 100).round()}%',
                              style: const TextStyle(color: Colors.white70)),
                        ),
                        _round(Icons.add, () {
                          final v = (_vol + 0.1).clamp(0.0, 1.0);
                          setState(() => _vol = v);
                          pc.setVolume(v);
                        }, size: 44, tip: 'Vol +'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
