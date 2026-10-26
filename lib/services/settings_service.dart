import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide settings. Liquid Glass is OFF by default (experimental).
class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._();
  SettingsService._();

  late SharedPreferences _p;
  bool ready = false;

  ThemeMode themeMode = ThemeMode.system;
  bool amoled = false;

  bool liquidGlassEnabled = false;
  String liquidGlassColorMode = 'system';
  Color liquidGlassCustomColor = const Color(0xFF6C9EFF);
  double liquidGlassOpacity = 0.18;
  double liquidGlassBlur = 18;

  bool saveSearchHistory = true;
  bool historyLocal = true;

  bool notificationSoundEnabled = true;
  String notificationSound = 'chime';

  final Map<String, bool> beta = {
    'listen_together': false,
    'friends_map': false,
    'private_chat': false,
    'karaoke_ai': false,
    'dual_session': false,
  };

  String? musicApiBaseOverride;
  /// color | blur | cinematic | dark | gradient | mesh
  String playerBgMode = 'color';
  /// normal | color | emotion
  String lyricsMode = 'color';
  /// header | nav | settings_only
  String mapEntry = 'nav';

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[
        (_p.getInt('theme_mode') ?? ThemeMode.system.index)
            .clamp(0, ThemeMode.values.length - 1)];
    amoled = _p.getBool('amoled') ?? false;
    liquidGlassEnabled = _p.getBool('lg_enabled') ?? false;
    liquidGlassColorMode = _p.getString('lg_color_mode') ?? 'system';
    liquidGlassOpacity = _p.getDouble('lg_opacity') ?? 0.18;
    liquidGlassBlur = _p.getDouble('lg_blur') ?? 18;
    final c = _p.getInt('lg_custom_color');
    if (c != null) liquidGlassCustomColor = Color(c);
    saveSearchHistory = _p.getBool('save_search_history') ?? true;
    historyLocal = _p.getBool('history_local') ?? true;
    notificationSoundEnabled = _p.getBool('notif_sound') ?? true;
    notificationSound = _p.getString('notif_sound_id') ?? 'chime';
    musicApiBaseOverride = _p.getString('music_api_base');
    playerBgMode = _p.getString('player_bg_mode') ?? 'color';
    lyricsMode = _p.getString('lyrics_mode') ?? 'color';
    mapEntry = _p.getString('map_entry') ?? 'nav';
    for (final k in beta.keys.toList()) {
      beta[k] = _p.getBool('beta_$k') ?? false;
    }
    ready = true;
    notifyListeners();
  }

  Future<void> _set(String key, Object? value) async {
    if (value is bool) {
      await _p.setBool(key, value);
    } else if (value is int) {
      await _p.setInt(key, value);
    } else if (value is double) {
      await _p.setDouble(key, value);
    } else if (value is String) {
      await _p.setString(key, value);
    } else if (value == null) {
      await _p.remove(key);
    }
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode m) async {
    themeMode = m;
    await _set('theme_mode', m.index);
  }

  Future<void> setLiquidGlassEnabled(bool v) async {
    liquidGlassEnabled = v;
    await _set('lg_enabled', v);
  }

  Future<void> setLiquidGlassColorMode(String v) async {
    liquidGlassColorMode = v;
    await _set('lg_color_mode', v);
  }

  Future<void> setLiquidGlassOpacity(double v) async {
    liquidGlassOpacity = v.clamp(0.05, 0.5);
    await _set('lg_opacity', liquidGlassOpacity);
  }

  Future<void> setLiquidGlassBlur(double v) async {
    liquidGlassBlur = v.clamp(4, 40);
    await _set('lg_blur', liquidGlassBlur);
  }

  Future<void> setLiquidGlassCustomColor(Color c) async {
    liquidGlassCustomColor = c;
    await _set('lg_custom_color', c.value);
  }

  Future<void> setSaveSearchHistory(bool v) async {
    saveSearchHistory = v;
    await _set('save_search_history', v);
  }

  Future<void> setNotificationSoundEnabled(bool v) async {
    notificationSoundEnabled = v;
    await _set('notif_sound', v);
  }

  Future<void> setNotificationSound(String id) async {
    notificationSound = id;
    await _set('notif_sound_id', id);
  }

  Future<void> setBeta(String key, bool v) async {
    beta[key] = v;
    await _set('beta_$key', v);
  }

  bool flag(String key) => beta[key] ?? false;

  Future<void> setMusicApiBase(String? url) async {
    musicApiBaseOverride = url?.trim().isEmpty == true ? null : url?.trim();
    await _set('music_api_base', musicApiBaseOverride);
  }

  Future<void> setPlayerBgMode(String mode) async {
    playerBgMode = mode;
    await _set('player_bg_mode', mode);
  }

  Future<void> setLyricsMode(String mode) async {
    lyricsMode = mode;
    await _set('lyrics_mode', mode);
  }

  Future<void> setMapEntry(String v) async {
    mapEntry = v;
    await _set('map_entry', v);
  }
}
