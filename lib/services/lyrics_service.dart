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

  /// Parse LRC → list of (seconds, line).
  /// Handles both line-level and word-level LRC (join words with spaces).
  List<({double t, String line})> parseLrc(String raw) {
    final tag = RegExp(r'\[(\d{1,2}):(\d{2})(?:\.(\d{1,3}))?\]');
    final out = <({double t, String line})>[];

    for (final rawLine in raw.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      final matches = tag.allMatches(line).toList();
      if (matches.isEmpty) continue;

      // Word-level: multiple tags on one physical line
      if (matches.length > 1) {
        final parts = <String>[];
        double? lineStart;
        for (var i = 0; i < matches.length; i++) {
          final m = matches[i];
          final start = m.end;
          final end = i + 1 < matches.length ? matches[i + 1].start : line.length;
          var word = line.substring(start, end).trim();
          if (word.isEmpty) continue;
          // strip leftover tags
          word = word.replaceAll(tag, '').trim();
          if (word.isEmpty) continue;
          parts.add(word);
          lineStart ??= _ts(m);
        }
        if (parts.isNotEmpty && lineStart != null) {
          out.add((t: lineStart, line: parts.join(' ')));
        }
        continue;
      }

      final m = matches.first;
      final text = line.substring(m.end).trim();
      if (text.isEmpty) continue;
      out.add((t: _ts(m), line: text));
    }
    out.sort((a, b) => a.t.compareTo(b.t));
    return out;
  }

  double _ts(RegExpMatch m) {
    final min = int.parse(m.group(1)!);
    final sec = int.parse(m.group(2)!);
    final ms = m.group(3);
    double frac = 0;
    if (ms != null) {
      final pad = ms.padRight(3, '0').substring(0, 3);
      frac = int.parse(pad) / 1000.0;
    }
    return min * 60 + sec + frac;
  }
}

