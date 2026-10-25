import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:pokke/services/player_controller.dart';

class ListenTogetherService extends ChangeNotifier {
  static final ListenTogetherService instance = ListenTogetherService._();
  ListenTogetherService._();

  String? roomCode;
  bool isHost = false;
  bool active = false;
  bool dualSession = false;
  Timer? _broadcast;

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
    _broadcast?.cancel();
    _broadcast = Timer.periodic(const Duration(seconds: 2), (_) {
      final pc = PlayerController.instance;
      debugPrint('lt host ${roomCode}: ${pc.current?['title']} @ ${pc.position}');
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
    return true;
  }

  void setDualSession(bool v) {
    dualSession = v;
    notifyListeners();
  }

  Future<void> leave() async {
    _broadcast?.cancel();
    active = false;
    isHost = false;
    roomCode = null;
    dualSession = false;
    notifyListeners();
  }
}
