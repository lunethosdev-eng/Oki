import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide settings. Liquid Glass is OFF by default (experimental).
class SettingsService extends ChangeNotifier {
  static final SettingsService instance = SettingsService._();
  SettingsService._();

  late SharedPreferences _p;
  bool ready = false;

  // Theme
  ThemeMode themeMode = ThemeMode.system;
  bool amoled = false;

  // Liquid Glass (experimental, off by default)
  bool liquidGlassEnabled = false;
  /// system | custom | mono
  String liquidGlassColorMode = 'system';
  Color liquidGlassCustomColor = const Color(0xFF6C9EFF);
  double liquidGlassOpacity = 0.18;
  double liquidGlassBlur = 18;

  // Search / privacy
  bool saveSearchHistory = true;
  bool historyLocal = true;

  // Notifications
  bool notificationSoundEnabled = true;
  String notificationSound = 'chime';

  // Beta flags (real features, gated)
  final Map<String, bool> beta = {
    'listen_together': false,
    'friends_map': false,
    'private_chat': false,
    'karaoke_ai': false,
    'dual_session': false,
  };

  // Music API override (owner)
  String? musicApiBaseOverride;

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
    for (final k in beta.keys.toList()) {
      beta[k] = _p.getBool('beta_$k') ?? false;
    }
    ready = true;
    notifyListeners();
  }

  Future<void> _set(String key, Object? value) async {
    if (value is bool) {
      await _p.setBool(key, value);
    } else if (value is double) {
      await _p.setDouble(key, value);
    } else if (value is int) {
      await _p.setInt(key, value);
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

  Future<void> setBeta(String key, bool v) async {
    beta[key] = v;
    await _set('beta_$key', v);
  }

  bool flag(String key) => beta[key] ?? false;

  Future<void> setMusicApiBase(String? url) async {
    musicApiBaseOverride = url?.trim().isEmpty == true ? null : url?.trim();
    await _set('music_api_base', musicApiBaseOverride);
  }
}
