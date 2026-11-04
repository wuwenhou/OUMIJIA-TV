import 'package:shared_preferences/shared_preferences.dart';

/// Lưu thông tin nhỏ tại máy: kênh xem cuối, kênh yêu thích, cỡ chữ.
class PrefsService {
  static const _kLastChannel = 'last_channel';
  static const _kFavorites = 'favorites';
  static const _kFontScale = 'font_scale';
  static const _kAutoPlay = 'auto_play';
  static const _kAutoUpdate = 'auto_update';

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---- Kênh xem lần cuối ----
  static String get lastChannelId => _prefs.getString(_kLastChannel) ?? 'vtv1';

  /// Ghi nhận mở kênh: cập nhật lastChannel + hàng "Vừa xem" (mới nhất đứng đầu).
  static Future<void> recordChannelOpened(String id) async {
    await _prefs.setString(_kLastChannel, id);
    final recents = recentChannelIds..remove(id);
    recents.insert(0, id);
    if (recents.length > 10) recents.removeRange(10, recents.length);
    await _prefs.setStringList(_kRecentChannels, recents);
  }

  // ---- Kênh vừa xem (dùng cho hàng Home, tối đa 10) ----
  static const _kRecentChannels = 'recent_channels';
  static List<String> get recentChannelIds =>
      _prefs.getStringList(_kRecentChannels) ?? [];

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

  // ---- Cập nhật ----
  static bool get autoUpdate => _prefs.getBool(_kAutoUpdate) ?? true;
  static Future<void> setAutoUpdate(bool v) => _prefs.setBool(_kAutoUpdate, v);

  // ---- Kiểu xem tab Kênh: danh sách (list) hay lưới (grid) ----
  static const _kGridView = 'channels_grid_view';
  static bool get gridView => _prefs.getBool(_kGridView) ?? false;
  static Future<void> setGridView(bool v) => _prefs.setBool(_kGridView, v);
}
