import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class PlayerController extends ChangeNotifier {
  static final PlayerController instance = PlayerController._();
  PlayerController._() {
    _player.onPlayerComplete.listen((_) => _onComplete());
    _player.onPositionChanged.listen((p) {
      position = p;
      notifyListeners();
    });
    _player.onDurationChanged.listen((d) {
      duration = d;
      notifyListeners();
    });
  }

  final AudioPlayer _player = AudioPlayer();
  Map<String, dynamic>? current;
  List<Map<String, dynamic>> queue = [];
  int queueIndex = 0;
  bool isPlaying = false;
  bool get playing => isPlaying;
  double volume = 1.0;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  /// 0 off, 1 all, 2 one
  int repeatMode = 0;
  bool shuffle = false;

  
  /// Alias used by Search / Artist screens
  Future<void> play(Map<String, dynamic> song,
      {List<Map<String, dynamic>>? asQueue, int? index}) async {
    if (asQueue != null && asQueue.isNotEmpty) {
      queue = List.from(asQueue);
      if (index != null && index >= 0 && index < queue.length) {
        queueIndex = index;
        song = queue[index];
      } else {
        queueIndex = queue.indexWhere((s) =>
            (s['id'] ?? s['title']) == (song['id'] ?? song['title']));
        if (queueIndex < 0) queueIndex = 0;
      }
    }
    await playSong(song, asQueue: asQueue);
  }

  Future<void> playSong(Map<String, dynamic> song,
      {List<Map<String, dynamic>>? asQueue}) async {
    if (asQueue != null && asQueue.isNotEmpty) {
      queue = List.from(asQueue);
      queueIndex = queue.indexWhere((s) =>
          (s['id'] ?? s['title']) == (song['id'] ?? song['title']));
      if (queueIndex < 0) queueIndex = 0;
    }
    current = song;
    final url =
        (song['audio_url'] ?? song['stream_url'] ?? song['url'] ?? '').toString();
    if (url.isEmpty) {
      debugPrint('playSong: no url');
      return;
    }
    try {
      await _player.stop();
      await _player.play(UrlSource(url));
      isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('playSong: $e');
    }
  }

  Future<void> toggle() async {
    if (current == null) return;
    if (isPlaying) {
      await _player.pause();
      isPlaying = false;
    } else {
      await _player.resume();
      isPlaying = true;
    }
    notifyListeners();
  }

  Future<void> seek(Duration d) async {
    await _player.seek(d);
    position = d;
    notifyListeners();
  }

  Future<void> next() async {
    if (queue.isEmpty) return;
    if (queueIndex >= queue.length - 1) {
      if (repeatMode == 1) {
        queueIndex = 0;
      } else {
        return;
      }
    } else {
      queueIndex++;
    }
    await playSong(queue[queueIndex]);
  }

  Future<void> previous() async {
    if (queue.isEmpty) return;
    if (position.inSeconds > 3) {
      await seek(Duration.zero);
      return;
    }
    if (queueIndex > 0) {
      queueIndex--;
      await playSong(queue[queueIndex]);
    }
  }

  Future<void> setVolume(double v) async {
    volume = v.clamp(0.0, 1.0);
    try {
      await _player.setVolume(volume);
    } catch (_) {}
    notifyListeners();
  }

  Future<void> pause() async {
    try {
      await _player.pause();
      isPlaying = false;
    } catch (_) {}
    notifyListeners();
  }

  Future<void> resume() async {
    try {
      await _player.resume();
      isPlaying = true;
    } catch (_) {}
    notifyListeners();
  }

  void cycleRepeat() {
    repeatMode = (repeatMode + 1) % 3;
    notifyListeners();
  }

  void toggleShuffle() {
    shuffle = !shuffle;
    if (shuffle && queue.length > 1) {
      final cur = current;
      queue.shuffle();
      if (cur != null) {
        queueIndex = queue.indexWhere(
            (s) => (s['id'] ?? s['title']) == (cur['id'] ?? cur['title']));
      }
    }
    notifyListeners();
  }

  Future<void> _onComplete() async {
    if (repeatMode == 2 && current != null) {
      await playSong(current!);
      return;
    }
    await next();
  }
}
