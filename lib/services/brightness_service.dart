import 'dart:io';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Độ sáng riêng của cửa sổ OUMIJIA TV (chỉ Android).
///
/// Cơ chế: MethodChannel `oumijia_tv/brightness` → Kotlin đổi
/// `WindowManager.LayoutParams.screenBrightness` của Activity.
/// - Không đổi độ sáng hệ thống, không cần quyền WRITE_SETTINGS.
/// - Thoát app: các ứng dụng khác không bị ảnh hưởng.
/// - Tắt công tắc: trả về chế độ độ sáng mặc định của Android.
class BrightnessService {
  static const _channel = MethodChannel('oumijia_tv/brightness');
  static const _kEnabled = 'custom_brightness_enabled';
  static const _kValue = 'custom_brightness_value';
  static const double defaultValue = 0.8;

  /// Chỉ Android có window-level brightness.
  static bool get supported => Platform.isAndroid;

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  /// Người dùng đã bật độ sáng tuỳ chỉnh chưa.
  static bool get enabledCached {
    // Đọc đồng bộ qua bộ nhớ đã nạp ở main() — xem [init].
    return _enabledCache && supported;
  }

  static bool _enabledCache = false;
  static double _valueCache = defaultValue;

  static double get valueCached => _valueCache;

  /// Nạp lựa chọn đã lưu và áp dụng lại khi mở app.
  static Future<void> init() async {
    if (!supported) return;
    final p = await _prefs();
    _enabledCache = p.getBool(_kEnabled) ?? false;
    _valueCache = (p.getDouble(_kValue) ?? defaultValue).clamp(0.0, 1.0);
    if (_enabledCache) {
      await _apply(_valueCache);
    }
  }

  /// Bật/tắt độ sáng tuỳ chỉnh.
  static Future<void> setEnabled(bool on) async {
    if (!supported) return;
    _enabledCache = on;
    final p = await _prefs();
    await p.setBool(_kEnabled, on);
    if (on) {
      await _apply(_valueCache);
    } else {
      await _restoreSystem();
    }
  }

  /// Lưu mức sáng mới (0.0 – 1.0); áp dụng ngay nếu đang bật.
  static Future<void> setValue(double v) async {
    final clamped = v.clamp(0.0, 1.0);
    _valueCache = clamped;
    final p = await _prefs();
    await p.setDouble(_kValue, clamped);
    if (_enabledCache) {
      await _apply(clamped);
    }
  }

  /// Trả về mức mặc định của hệ thống (tắt tuỳ chỉnh).
  static Future<void> reset() async {
    _enabledCache = false;
    _valueCache = defaultValue;
    final p = await _prefs();
    await p.setBool(_kEnabled, false);
    await p.setDouble(_kValue, defaultValue);
    await _restoreSystem();
  }

  static Future<void> _apply(double v) async {
    try {
      await _channel.invokeMethod('setBrightness', v);
    } on MissingPluginException {
      // Nền tảng không hỗ trợ (hoặc chưa build lại) — bỏ qua an toàn.
    } catch (_) {}
  }

  static Future<void> _restoreSystem() async {
    try {
      await _channel.invokeMethod('setBrightness', -1.0);
    } on MissingPluginException {
      // không có native channel
    } catch (_) {}
  }
}
