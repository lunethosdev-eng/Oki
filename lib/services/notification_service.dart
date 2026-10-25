import 'package:audioplayers/audioplayers.dart';
import 'package:pokke/services/settings_service.dart';

/// Local notification tones (media session controls = next iteration with audio_service).
class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  final _player = AudioPlayer();

  static const tones = {
    'message': 'sounds/tone_message.mp3',
    'joyous': 'sounds/tone_joyous.mp3',
    'bubble': 'sounds/tone_bubble.mp3',
    'twinkle': 'sounds/tone_twinkle.mp3',
    'marimba': 'sounds/tone_marimba.mp3',
    'chime': 'sounds/tone_chime.mp3',
  };

  Future<void> playTone([String? id]) async {
    final s = SettingsService.instance;
    if (!s.notificationSoundEnabled) return;
    final key = id ?? s.notificationSound;
    final path = tones[key] ?? tones['chime']!;
    try {
      await _player.stop();
      await _player.play(AssetSource(path));
    } catch (_) {}
  }
}
