import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:pokke/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// TV ↔ phone account linking via one-time code / QR payload.
class DeviceLinkService extends ChangeNotifier {
  static final DeviceLinkService instance = DeviceLinkService._();
  DeviceLinkService._();

  String? pendingCode;
  String? pendingPayload; // for QR
  Timer? _expire;
  StreamSubscription? _sub;

  String _gen() {
    const c = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => c[r.nextInt(c.length)]).join();
  }

  /// TV starts pairing: shows code + QR, waits for phone to confirm.
  Future<String> startTvPairing() async {
    pendingCode = _gen();
    pendingPayload = jsonEncode({
      't': 'pokke_link',
      'c': pendingCode,
      'v': 1,
    });
    notifyListeners();

    if (SupabaseService.isLoggedIn) {
      // rare: TV already has session
    }

    try {
      await SupabaseService.kokoro.from('device_links').upsert({
        'code': pendingCode,
        'status': 'waiting',
        'created_at': DateTime.now().toIso8601String(),
        'expires_at':
            DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
      });
    } catch (e) {
      debugPrint('device_link upsert: $e');
    }

    _sub?.cancel();
    try {
      _sub = SupabaseService.kokoro
          .from('device_links')
          .stream(primaryKey: ['code'])
          .eq('code', pendingCode!)
          .listen((rows) async {
        if (rows.isEmpty) return;
        final row = rows.first;
        if (row['status'] == 'claimed' && row['access_token'] != null) {
          await _applySession(
            access: row['access_token']?.toString() ?? '',
            refresh: row['refresh_token']?.toString() ?? '',
          );
        }
      });
    } catch (e) {
      debugPrint('device_link stream: $e');
    }

    _expire?.cancel();
    _expire = Timer(const Duration(minutes: 5), () {
      pendingCode = null;
      pendingPayload = null;
      notifyListeners();
    });
    return pendingCode!;
  }

  /// Phone (logged in) claims a TV code → pushes tokens to row.
  Future<bool> claimFromPhone(String code) async {
    final c = code.trim().toUpperCase();
    if (c.length < 4) return false;
    if (!SupabaseService.isLoggedIn || SupabaseService.isGuest) return false;
    final session = SupabaseService.kokoro.auth.currentSession;
    if (session == null) return false;
    try {
      await SupabaseService.kokoro.from('device_links').update({
        'status': 'claimed',
        'user_id': SupabaseService.currentUser!.id,
        'access_token': session.accessToken,
        'refresh_token': session.refreshToken,
        'claimed_at': DateTime.now().toIso8601String(),
      }).eq('code', c).eq('status', 'waiting');
      return true;
    } catch (e) {
      debugPrint('claim: $e');
      return false;
    }
  }

  Future<void> _applySession(
      {required String access, required String refresh}) async {
    if (access.isEmpty) return;
    try {
      await SupabaseService.kokoro.auth.setSession(access);
      // persist
      final p = await SharedPreferences.getInstance();
      await p.setString('linked_session', access);
      pendingCode = null;
      pendingPayload = null;
      notifyListeners();
    } catch (e) {
      debugPrint('apply session: $e');
    }
  }

  void cancel() {
    _expire?.cancel();
    _sub?.cancel();
    pendingCode = null;
    pendingPayload = null;
    notifyListeners();
  }
}
