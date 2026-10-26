import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:pokke/services/supabase_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Phone ↔ TV / other device account linking via one-time code.
class DeviceLinkService extends ChangeNotifier {
  static final DeviceLinkService instance = DeviceLinkService._();
  DeviceLinkService._();

  String? pendingCode;
  String? pendingPayload;
  bool linked = false;
  Timer? _expire;
  StreamSubscription? _sub;
  Timer? _poll;

  String _gen() {
    const c = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(6, (_) => c[r.nextInt(c.length)]).join();
  }

  /// Host device (TV or second phone) shows code and waits.
  Future<String> startHostPairing() async {
    pendingCode = _gen();
    pendingPayload = jsonEncode({
      't': 'pokke_link',
      'c': pendingCode,
      'v': 1,
    });
    linked = false;
    notifyListeners();

    try {
      await SupabaseService.kokoro.from('device_links').upsert({
        'code': pendingCode,
        'status': 'waiting',
        'user_id': null,
        'access_token': null,
        'refresh_token': null,
        'created_at': DateTime.now().toIso8601String(),
        'expires_at':
            DateTime.now().add(const Duration(minutes: 5)).toIso8601String(),
        'claimed_at': null,
      });
    } catch (e) {
      debugPrint('device_link upsert: $e');
    }

    _sub?.cancel();
    _poll?.cancel();

    // Poll every 2s (more reliable than realtime for one-shot)
    _poll = Timer.periodic(const Duration(seconds: 2), (_) => _checkClaimed());

    try {
      _sub = SupabaseService.kokoro
          .from('device_links')
          .stream(primaryKey: ['code'])
          .eq('code', pendingCode!)
          .listen((rows) async {
        if (rows.isEmpty) return;
        await _handleRow(Map<String, dynamic>.from(rows.first));
      });
    } catch (e) {
      debugPrint('device_link stream: $e');
    }

    _expire?.cancel();
    _expire = Timer(const Duration(minutes: 5), () {
      pendingCode = null;
      pendingPayload = null;
      _poll?.cancel();
      notifyListeners();
    });
    return pendingCode!;
  }

  Future<void> _checkClaimed() async {
    if (pendingCode == null || linked) return;
    try {
      final row = await SupabaseService.kokoro
          .from('device_links')
          .select()
          .eq('code', pendingCode!)
          .maybeSingle();
      if (row != null) {
        await _handleRow(Map<String, dynamic>.from(row));
      }
    } catch (_) {}
  }

  Future<void> _handleRow(Map<String, dynamic> row) async {
    if (row['status'] != 'claimed') return;
    final refresh = row['refresh_token']?.toString() ?? '';
    final access = row['access_token']?.toString() ?? '';
    if (refresh.isEmpty && access.isEmpty) return;
    await _applySession(access: access, refresh: refresh);
  }

  /// Logged-in device claims the host code.
  Future<bool> claimFromPhone(String code) async {
    final c = code.trim().toUpperCase();
    if (c.length < 4) return false;
    if (!SupabaseService.isLoggedIn || SupabaseService.isGuest) return false;
    final session = SupabaseService.kokoro.auth.currentSession;
    if (session == null) return false;
    try {
      final updated = await SupabaseService.kokoro
          .from('device_links')
          .update({
            'status': 'claimed',
            'user_id': SupabaseService.currentUser!.id,
            'access_token': session.accessToken,
            'refresh_token': session.refreshToken,
            'claimed_at': DateTime.now().toIso8601String(),
          })
          .eq('code', c)
          .eq('status', 'waiting')
          .select();
      return (updated as List).isNotEmpty;
    } catch (e) {
      debugPrint('claim: $e');
      return false;
    }
  }

  Future<void> _applySession(
      {required String access, required String refresh}) async {
    try {
      if (refresh.isNotEmpty) {
        // supabase_flutter: setSession expects the refresh token
        await SupabaseService.kokoro.auth.setSession(refresh);
      } else if (access.isNotEmpty) {
        // fallback: persist and recover
        final payload = jsonEncode({
          'access_token': access,
          'refresh_token': refresh,
          'token_type': 'bearer',
        });
        await SupabaseService.kokoro.auth.recoverSession(payload);
      }
      final p = await SharedPreferences.getInstance();
      await p.setBool('device_linked', true);
      linked = true;
      pendingCode = null;
      pendingPayload = null;
      _poll?.cancel();
      notifyListeners();
    } catch (e) {
      debugPrint('apply session: $e');
    }
  }

  void cancel() {
    _expire?.cancel();
    _sub?.cancel();
    _poll?.cancel();
    pendingCode = null;
    pendingPayload = null;
    notifyListeners();
  }
}
