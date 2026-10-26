import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pokke/services/supabase_service.dart';

class OfflineService extends ChangeNotifier {
  static final OfflineService instance = OfflineService._();
  OfflineService._();

  bool downloadingCatalog = false;
  int catalogDone = 0;
  int catalogTotal = 0;
  String? lastError;

  Future<Directory> _pokkeDir() async {
    Directory base;
    if (Platform.isAndroid) {
      // Prefer public Music if possible, else app docs
      final ext = Directory('/storage/emulated/0/Music/Pokke');
      try {
        if (!await ext.exists()) await ext.create(recursive: true);
        final test = File('${ext.path}/.pokke_write');
        await test.writeAsString('ok');
        await test.delete();
        base = ext;
      } catch (_) {
        final docs = await getApplicationDocumentsDirectory();
        base = Directory('${docs.path}/Pokke');
        if (!await base.exists()) await base.create(recursive: true);
      }
    } else {
      final docs = await getApplicationDocumentsDirectory();
      base = Directory('${docs.path}/Pokke');
      if (!await base.exists()) await base.create(recursive: true);
    }
    return base;
  }

  Future<String?> localPathFor(String songId) async {
    final p = await SharedPreferences.getInstance();
    return p.getString('offline_$songId');
  }

  Future<bool> isDownloaded(String songId) async {
    final path = await localPathFor(songId);
    return path != null && File(path).existsSync();
  }

  Future<bool> downloadSong(Map<String, dynamic> song) async {
    final id = song['id']?.toString() ?? song['title']?.toString() ?? '';
    final url = (song['audio_url'] ?? song['url'] ?? song['file_url'])
        ?.toString();
    if (id.isEmpty || url == null || !url.startsWith('http')) {
      lastError = 'Sin URL de audio';
      return false;
    }
    try {
      final dir = await _pokkeDir();
      final safe = id.replaceAll(RegExp(r'[^\w\-]'), '_');
      final file = File('${dir.path}/$safe.mp3');
      final res = await http.get(Uri.parse(url));
      if (res.statusCode != 200) {
        lastError = 'HTTP ${res.statusCode}';
        return false;
      }
      await file.writeAsBytes(res.bodyBytes);
      final p = await SharedPreferences.getInstance();
      await p.setString('offline_$id', file.path);
      notifyListeners();
      return true;
    } catch (e) {
      lastError = '$e';
      debugPrint('offline download: $e');
      return false;
    }
  }

  Future<void> downloadCatalog() async {
    if (downloadingCatalog) return;
    downloadingCatalog = true;
    catalogDone = 0;
    notifyListeners();
    try {
      final songs = await SupabaseService.getSongs(limit: 500);
      catalogTotal = songs.length;
      notifyListeners();
      for (final s in songs) {
        await downloadSong(s);
        catalogDone++;
        notifyListeners();
      }
    } finally {
      downloadingCatalog = false;
      notifyListeners();
    }
  }

  String etaLabel() {
    if (catalogTotal == 0) return '…';
    final left = catalogTotal - catalogDone;
    // ~4s per track heuristic
    final sec = left * 4;
    if (sec < 60) return '~$sec s';
    return '~${(sec / 60).ceil()} min';
  }
}
