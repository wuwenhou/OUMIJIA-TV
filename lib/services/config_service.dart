import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models.dart';

/// Tải và cache cấu hình nội dung.
///
/// Thứ tự ưu tiên:
/// 1. File cấu hình trên GitHub (luôn mới nhất — chủ app sửa là app cập nhật)
/// 2. Cache lần tải gần nhất (dùng khi mất mạng)
/// 3. File đóng gói sẵn trong app (assets)
class ConfigService {
  static const remoteUrl =
      'https://raw.githubusercontent.com/wuwenhou/OUMIJIA-TV/main/config/channels.json';
  static const cacheKey = 'config_cache_v1';

  /// Nạp cấu hình: thử remote → cache → bundled.
  static Future<AppConfig> load() async {
    // 1. Remote
    try {
      final resp = await http
          .get(Uri.parse(remoteUrl))
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode == 200) {
        final body = utf8.decode(resp.bodyBytes);
        final json = jsonDecode(body) as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, body);
        return AppConfig.fromJson(json, source: 'remote');
      }
    } catch (_) {
      // Mất mạng / GitHub chậm → dùng cache bên dưới
    }

    // 2. Cache
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final json = jsonDecode(cached) as Map<String, dynamic>;
        return AppConfig.fromJson(json, source: 'cache');
      }
    } catch (_) {}

    // 3. Bundled asset (đóng gói sẵn trong app)
    final raw = await rootBundle.loadString('assets/config/channels.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    return AppConfig.fromJson(json, source: 'bundled');
  }
}
