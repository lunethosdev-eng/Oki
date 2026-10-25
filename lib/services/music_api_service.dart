import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pokke/services/settings_service.dart';
import 'package:pokke/services/supabase_service.dart';

class MusicApiService {
  static String? _cached;

  static Future<String> get baseUrl async {
    final override = SettingsService.instance.musicApiBaseOverride;
    if (override != null && override.isNotEmpty) return override;
    if (_cached != null) return _cached!;
    try {
      final row = await SupabaseService.kokoro
          .from('app_config')
          .select('value')
          .eq('key', 'music_api_base')
          .maybeSingle();
      _cached = row?['value']?.toString() ??
          'https://creatures-band-wearing-partners.trycloudflare.com';
    } catch (_) {
      _cached = 'https://creatures-band-wearing-partners.trycloudflare.com';
    }
    return _cached!;
  }

  static void clearCache() => _cached = null;

  static Future<List<Map<String, dynamic>>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];
    try {
      final local = await SupabaseService.searchSongs(q, limit: 20);
      if (local.isNotEmpty) return local;
    } catch (_) {}
    try {
      final base = await baseUrl;
      final uri =
          Uri.parse('$base/api/search').replace(queryParameters: {'q': q});
      final res = await http.get(uri).timeout(const Duration(seconds: 45));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (data is Map && data['results'] is List) {
        return (data['results'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}
    return [];
  }
}
