import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pokke/services/settings_service.dart';
import 'package:pokke/services/supabase_service.dart';

/// Music download / search server (owner-configurable base URL).
/// Endpoints:
///  GET /api/search?q=
///  GET /api/autocomplete?q=
///  GET /api/artist/releases?artist=&since=
///  GET /api/songs
///  GET /api/progress?id=
///  GET /api/progress-stream (SSE)
///  GET /api/logs
class MusicApiService {
  static String? _cached;

  static Future<String> get baseUrl async {
    final override = SettingsService.instance.musicApiBaseOverride;
    if (override != null && override.isNotEmpty) {
      return override.replaceAll(RegExp(r'/+$'), '');
    }
    if (_cached != null) return _cached!;
    try {
      final row = await SupabaseService.kokoro
          .from('app_config')
          .select('value')
          .eq('key', 'music_api_base')
          .maybeSingle();
      _cached = (row?['value']?.toString() ??
              'https://creatures-band-wearing-partners.trycloudflare.com')
          .replaceAll(RegExp(r'/+$'), '');
    } catch (_) {
      _cached = 'https://creatures-band-wearing-partners.trycloudflare.com';
    }
    return _cached!;
  }

  static Future<void> setGlobalBase(String url) async {
    final clean = url.trim().replaceAll(RegExp(r'/+$'), '');
    await SettingsService.instance.setMusicApiBase(clean);
    try {
      await SupabaseService.kokoro.from('app_config').upsert({
        'key': 'music_api_base',
        'value': clean,
      });
    } catch (_) {}
    clearCache();
  }

  static void clearCache() => _cached = null;

  static Future<List<Map<String, dynamic>>> search(String query) async {
    final q = query.trim();
    if (q.isEmpty) return [];

    // 1) Local Ukiyo catalog first
    List<Map<String, dynamic>> local = [];
    try {
      local = await SupabaseService.searchSongs(q, limit: 30);
    } catch (_) {}

    // 2) Remote server (download / enrich if missing)
    List<Map<String, dynamic>> remote = [];
    try {
      final base = await baseUrl;
      final uri =
          Uri.parse('$base/api/search').replace(queryParameters: {'q': q});
      final res = await http.get(uri).timeout(const Duration(seconds: 60));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          remote = data
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        } else if (data is Map) {
          if (data['results'] is List) {
            remote = (data['results'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          } else if (data['song'] is Map) {
            remote = [Map<String, dynamic>.from(data['song'] as Map)];
          } else {
            // single song object
            if (data['title'] != null || data['audio_url'] != null) {
              remote = [Map<String, dynamic>.from(data)];
            }
          }
        }
      }
    } catch (_) {}

    // Merge: local first, then remote not duplicated by title+artist
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final s in [...local, ...remote]) {
      final key =
          '${(s['title'] ?? '').toString().toLowerCase()}|${(s['artist'] ?? '').toString().toLowerCase()}';
      if (seen.add(key)) out.add(s);
    }
    return out;
  }

  static Future<List<Map<String, dynamic>>> autocomplete(String text) async {
    final q = text.trim();
    if (q.length < 2) return [];
    try {
      final base = await baseUrl;
      final uri = Uri.parse('$base/api/autocomplete')
          .replace(queryParameters: {'q': q});
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return [];
      final data = jsonDecode(res.body);
      if (data is List) {
        return data
            .map((e) => e is Map
                ? Map<String, dynamic>.from(e)
                : {'title': e.toString()})
            .toList();
      }
      if (data is Map && data['suggestions'] is List) {
        return (data['suggestions'] as List)
            .map((e) => e is Map
                ? Map<String, dynamic>.from(e)
                : {'title': e.toString()})
            .toList();
      }
    } catch (_) {}
    // fallback local
    return SupabaseService.searchSongs(q, limit: 8);
  }

  static Future<List<Map<String, dynamic>>> latestSongs() async {
    try {
      final base = await baseUrl;
      final res = await http
          .get(Uri.parse('$base/api/songs'))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
    } catch (_) {}
    return SupabaseService.getSongs(limit: 50);
  }

  static Future<List<Map<String, dynamic>>> artistReleases(String artist,
      {String? since}) async {
    try {
      final base = await baseUrl;
      final params = {'artist': artist};
      if (since != null) params['since'] = since;
      final uri = Uri.parse('$base/api/artist/releases')
          .replace(queryParameters: params);
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data is List) {
          return data
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
      }
    } catch (_) {}
    // fallback: search by artist name in Ukiyo
    return SupabaseService.searchSongs(artist, limit: 50);
  }

  static Future<Map<String, dynamic>?> progress(String youtubeId) async {
    try {
      final base = await baseUrl;
      final uri = Uri.parse('$base/api/progress')
          .replace(queryParameters: {'id': youtubeId});
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(res.body) as Map);
      }
    } catch (_) {}
    return null;
  }
}
