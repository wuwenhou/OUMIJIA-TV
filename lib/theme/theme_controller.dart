import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'design_system.dart';

/// Cài đặt giao diện: mode (light/dark/system), accent, độ lớn chữ.
/// Lưu tại thiết bị, không cần đăng nhập.
class ThemeSettings {
  final ThemeMode mode;
  final String accentKey;
  final double fontScale; // 0.9 – 1.3

  const ThemeSettings({
    this.mode = ThemeMode.system,
    this.accentKey = 'gold',
    this.fontScale = 1.0,
  });

  bool get isDefault =>
      mode == ThemeMode.system && accentKey == 'gold' && fontScale == 1.0;

  ThemeSettings copyWith({
    ThemeMode? mode,
    String? accentKey,
    double? fontScale,
  }) =>
      ThemeSettings(
        mode: mode ?? this.mode,
        accentKey: accentKey ?? this.accentKey,
        fontScale: fontScale ?? this.fontScale,
      );
}

class ThemeController extends ValueNotifier<ThemeSettings> {
  static ThemeController? _instance;
  static const _kMode = 'theme_mode';
  static const _kAccent = 'theme_accent';
  static const _kFontScale = 'display_font_scale';

  ThemeController(super.value);

  static ThemeController get instance => _instance ??= ThemeController(const ThemeSettings());

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    value = ThemeSettings(
      mode: _modeOf(p.getString(_kMode)),
      accentKey: p.getString(_kAccent) ?? 'gold',
      fontScale: (p.getDouble(_kFontScale) ?? 1.0).clamp(0.9, 1.3),
    );
  }

  ThemeMode _modeOf(String? s) {
    switch (s) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setMode(ThemeMode m) async {
    value = value.copyWith(mode: m);
    await _persist();
  }

  Future<void> setAccent(String key) async {
    value = value.copyWith(accentKey: kAccentKeys.contains(key) ? key : 'gold');
    await _persist();
  }

  Future<void> setFontScale(double v) async {
    value = value.copyWith(fontScale: v.clamp(0.9, 1.3));
    await _persist();
  }

  /// Khôi phục toàn bộ về mặc định.
  Future<void> resetToDefault() async {
    value = const ThemeSettings();
    await _persist();
  }

  Future<void> _persist() async {
    final p = await SharedPreferences.getInstance();
    final m = switch (value.mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    };
    await p.setString(_kMode, m);
    await p.setString(_kAccent, value.accentKey);
    await p.setDouble(_kFontScale, value.fontScale);
  }
}
