import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceSearchService {
  static final VoiceSearchService instance = VoiceSearchService._();
  VoiceSearchService._();

  final _stt = SpeechToText();
  bool ready = false;
  String localeId = 'es_ES';

  Future<bool> init() async {
    try {
      ready = await _stt.initialize(
        onError: (e) => debugPrint('stt error $e'),
        onStatus: (s) => debugPrint('stt $s'),
      );
      final locales = await _stt.locales();
      // Prefer Spanish, then system
      for (final l in locales) {
        if (l.localeId.startsWith('es')) {
          localeId = l.localeId;
          break;
        }
      }
      return ready;
    } catch (e) {
      debugPrint('stt init $e');
      return false;
    }
  }

  Future<String?> listenOnce({Duration timeout = const Duration(seconds: 6)}) async {
    if (!ready) {
      final ok = await init();
      if (!ok) return null;
    }
    final buf = StringBuffer();
    final done = _stt.listen(
      localeId: localeId,
      listenFor: timeout,
      pauseFor: const Duration(seconds: 2),
      onResult: (r) {
        buf.clear();
        buf.write(r.recognizedWords);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
    );
    await Future.delayed(timeout + const Duration(milliseconds: 400));
    await _stt.stop();
    final text = buf.toString().trim();
    return text.isEmpty ? null : text;
  }

  Future<void> stop() => _stt.stop();
}
