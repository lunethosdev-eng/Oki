import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:pokke/services/player_controller.dart';
import 'package:pokke/services/supabase_service.dart';

class ListenTogetherService extends ChangeNotifier {
  static final ListenTogetherService instance = ListenTogetherService._();
  ListenTogetherService._();

  String? roomCode;
  bool isHost = false;
  bool active = false;
  bool dualSession = false;
  Timer? _broadcast;
  StreamSubscription? _roomSub;
  Map<String, dynamic>? roomState;

  String _code() {
    const c = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => c[r.nextInt(c.length)]).join();
  }

  Future<String?> host() async {
    roomCode = _code();
    isHost = true;
    active = true;
    notifyListeners();

    if (SupabaseService.isLoggedIn && !SupabaseService.isGuest) {
      try {
        await SupabaseService.kokoro.from('listen_rooms').upsert({
          'code': roomCode,
          'host_id': SupabaseService.currentUser!.id,
          'active': true,
          'updated_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('lt host upsert: $e');
      }
    }

    _broadcast?.cancel();
    _broadcast = Timer.periodic(const Duration(seconds: 2), (_) async {
      final pc = PlayerController.instance;
      final payload = {
        'code': roomCode,
        'song_id': pc.current?['id'],
        'title': pc.current?['title'],
        'artist': pc.current?['artist'],
        'audio_url': pc.current?['audio_url'] ?? pc.current?['url'],
        'cover_url': pc.current?['cover_url'],
        'position_ms': pc.position.inMilliseconds,
        'playing': pc.isPlaying,
        'updated_at': DateTime.now().toIso8601String(),
      };
      if (SupabaseService.isLoggedIn && !SupabaseService.isGuest) {
        try {
          await SupabaseService.kokoro
              .from('listen_rooms')
              .update(payload)
              .eq('code', roomCode!);
        } catch (_) {}
      }
      debugPrint('lt host $roomCode: ${payload['title']} @ ${payload['position_ms']}');
    });
    return roomCode;
  }

  Future<bool> join(String code) async {
    final c = code.trim().toUpperCase();
    if (c.length < 4) return false;
    roomCode = c;
    isHost = false;
    active = true;
    notifyListeners();

    try {
      final row = await SupabaseService.kokoro
          .from('listen_rooms')
          .select()
          .eq('code', c)
          .maybeSingle();
      if (row != null) {
        roomState = Map<String, dynamic>.from(row);
        await _applyRoomState(roomState!);
      }
    } catch (_) {}

    try {
      _roomSub?.cancel();
      _roomSub = SupabaseService.kokoro
          .from('listen_rooms')
          .stream(primaryKey: ['code'])
          .eq('code', c)
          .listen((rows) async {
        if (rows.isEmpty) return;
        roomState = Map<String, dynamic>.from(rows.first);
        await _applyRoomState(roomState!);
        notifyListeners();
      });
    } catch (e) {
      debugPrint('lt join stream: $e');
    }
    return true;
  }

  Future<void> _applyRoomState(Map<String, dynamic> s) async {
    if (isHost) return;
    final pc = PlayerController.instance;
    final url = (s['audio_url'] ?? '').toString();
    final title = s['title']?.toString();
    if (url.isEmpty) return;
    final curUrl = (pc.current?['audio_url'] ?? pc.current?['url'] ?? '').toString();
    if (curUrl != url) {
      await pc.playSong({
        'title': title ?? 'Listen together',
        'artist': s['artist'] ?? '',
        'audio_url': url,
        'cover_url': s['cover_url'],
        'id': s['song_id'],
      });
    }
    final posMs = (s['position_ms'] as num?)?.toInt() ?? 0;
    final target = Duration(milliseconds: posMs);
    if ((pc.position - target).inMilliseconds.abs() > 1500) {
      await pc.seek(target);
    }
    final shouldPlay = s['playing'] == true;
    if (shouldPlay && !pc.isPlaying) await pc.toggle();
    if (!shouldPlay && pc.isPlaying) await pc.toggle();
  }

  void setDualSession(bool v) {
    dualSession = v;
    notifyListeners();
  }

  Future<void> leave() async {
    _broadcast?.cancel();
    await _roomSub?.cancel();
    if (isHost && roomCode != null && SupabaseService.isLoggedIn) {
      try {
        await SupabaseService.kokoro
            .from('listen_rooms')
            .update({'active': false}).eq('code', roomCode!);
      } catch (_) {}
    }
    active = false;
    isHost = false;
    roomCode = null;
    dualSession = false;
    roomState = null;
    notifyListeners();
  }
}
