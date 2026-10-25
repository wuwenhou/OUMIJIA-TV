import 'package:shared_preferences/shared_preferences.dart';

/// Lưu thông tin nhỏ tại máy: kênh xem cuối, kênh yêu thích, cỡ chữ.
class PrefsService {
  static const _kLastChannel = 'last_channel';
  static const _kFavorites = 'favorites';
  static const _kFontScale = 'font_scale';
  static const _kAutoPlay = 'auto_play';
  static const _kVoiceEnabled = 'voice_enabled';

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---- Kênh xem lần cuối ----
  static String get lastChannelId => _prefs.getString(_kLastChannel) ?? 'vtv1';
  static Future<void> setLastChannel(String id) =>
      _prefs.setString(_kLastChannel, id);

  // ---- Kênh yêu thích ----
  static List<String> get favorites => _prefs.getStringList(_kFavorites) ?? [];
  static bool isFavorite(String id) => favorites.contains(id);
  static Future<void> toggleFavorite(String id) async {
    final list = favorites;
    if (list.contains(id)) {
      list.remove(id);
    } else {
      list.add(id);
    }
    await _prefs.setStringList(_kFavorites, list);
  }

  // ---- Cỡ chữ: 1.0 / 1.2 / 1.4 ----
  static double get fontScale => _prefs.getDouble(_kFontScale) ?? 1.0;
  static Future<void> setFontScale(double v) => _prefs.setDouble(_kFontScale, v);

  // ---- Tự phát khi mở app ----
  static bool get autoPlay => _prefs.getBool(_kAutoPlay) ?? true;
  static Future<void> setAutoPlay(bool v) => _prefs.setBool(_kAutoPlay, v);

  // ---- Giọng nói ----
  static bool get voiceEnabled => _prefs.getBool(_kVoiceEnabled) ?? true;
  static Future<void> setVoiceEnabled(bool v) => _prefs.setBool(_kVoiceEnabled, v);
}
