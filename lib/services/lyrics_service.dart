import 'dart:convert';
import 'package:http/http.dart' as http;

class LyricsService {
  static final LyricsService instance = LyricsService._();
  LyricsService._();

  /// Plain or LRC lyrics. Tries LRCLIB public API (no key).
  Future<String?> fetch({
    required String title,
    required String artist,
    int? durationSec,
  }) async {
    try {
      final uri = Uri.https('lrclib.net', '/api/search', {
        'track_name': title,
        'artist_name': artist,
      });
      final res = await http.get(uri, headers: {
        'User-Agent': 'Pokke/2.0 (music app)',
      }).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) return null;
      final list = jsonDecode(res.body);
      if (list is! List || list.isEmpty) return null;
      Map<String, dynamic>? best;
      for (final e in list) {
        if (e is Map) {
          best = Map<String, dynamic>.from(e);
          break;
        }
      }
      if (best == null) return null;
      final synced = best['syncedLyrics']?.toString();
      final plain = best['plainLyrics']?.toString();
      if (synced != null && synced.trim().isNotEmpty) return synced;
      if (plain != null && plain.trim().isNotEmpty) return plain;
    } catch (_) {}
    return null;
  }

  /// Parse LRC → list of (seconds, line)
  List<({double t, String line})> parseLrc(String raw) {
    final out = <({double t, String line})>[];
    final re = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\](.*)');
    for (final line in raw.split('\n')) {
      final m = re.firstMatch(line.trim());
      if (m == null) continue;
      final min = int.parse(m.group(1)!);
      final sec = int.parse(m.group(2)!);
      final ms = m.group(3);
      double frac = 0;
      if (ms != null) {
        final pad = ms.padRight(3, '0').substring(0, 3);
        frac = int.parse(pad) / 1000.0;
      }
      final t = min * 60 + sec + frac;
      final text = m.group(4)?.trim() ?? '';
      if (text.isEmpty) continue;
      out.add((t: t, line: text));
    }
    out.sort((a, b) => a.t.compareTo(b.t));
    return out;
  }
}
