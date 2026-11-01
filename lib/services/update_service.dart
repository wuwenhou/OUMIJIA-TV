import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

/// Cơ chế cập nhật trong app (chủ yếu cho Android).
///
/// - Kiểm tra bản mới nhất trên GitHub Releases
/// - So sánh version với app đang chạy
/// - Tải APK về máy + mở trình cài đặt
class UpdateService {
  static const repo = 'wuwenhou/OUMIJIA-TV';
  static const apiUrl = 'https://api.github.com/repos/$repo/releases/latest';

  /// Thông tin bản cập nhật (nếu có).
  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final resp = await http
          .get(Uri.parse(apiUrl), headers: {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode != 200) return null;

      final json = jsonDecode(resp.body) as Map<String, dynamic>;
      final tag = (json['tag_name'] as String?) ?? '';
      final version = tag.replaceFirst(RegExp(r'^v'), '');
      if (version.isEmpty) return null;

      // Tìm file APK trong assets của release
      final assets = json['assets'] as List<dynamic>? ?? [];
      Map<String, dynamic>? apkAsset;
      for (final a in assets) {
        final m = a as Map<String, dynamic>;
        final name = (m['name'] as String?) ?? '';
        if (name.toLowerCase().endsWith('.apk')) {
          apkAsset = m;
          break;
        }
      }
      if (apkAsset == null) return null;

      final current = await PackageInfo.fromPlatform();
      if (!_isNewer(version, current.version)) return null;

      return UpdateInfo(
        version: version,
        tagName: tag,
        apkUrl: apkAsset['browser_download_url'] as String,
        apkSize: (apkAsset['size'] as num?)?.toInt() ?? 0,
        releaseNotes: (json['body'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// Tải APK về thư mục cache, gọi onProgress(0..1).
  static Future<File> downloadApk(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/OUMIJIA-TV-${info.version}.apk');

    final client = http.Client();
    try {
      final req = http.Request('GET', Uri.parse(info.apkUrl));
      final resp = await client.send(req);
      if (resp.statusCode != 200) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final total = resp.contentLength ?? info.apkSize;
      final sink = file.openWrite();
      int received = 0;
      await for (final chunk in resp.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0 && onProgress != null) {
          onProgress(received / total);
        }
      }
      await sink.close();
      return file;
    } finally {
      client.close();
    }
  }

  /// Mở trình cài đặt APK.
  static Future<void> installApk(File file) async {
    await OpenFilex.open(file.path);
  }

  /// So sánh version "x.y.z" — trả true nếu [remote] > [current].
  static bool _isNewer(String remote, String current) {
    final r = _parse(remote);
    final c = _parse(current);
    for (var i = 0; i < 3; i++) {
      if (r[i] > c[i]) return true;
      if (r[i] < c[i]) return false;
    }
    return false;
  }

  static List<int> _parse(String v) {
    final parts = v.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    while (parts.length < 3) {
      parts.add(0);
    }
    return parts.take(3).toList();
  }
}

class UpdateInfo {
  final String version;
  final String tagName;
  final String apkUrl;
  final int apkSize;
  final String releaseNotes;

  UpdateInfo({
    required this.version,
    required this.tagName,
    required this.apkUrl,
    required this.apkSize,
    required this.releaseNotes,
  });

  String get sizeText {
    if (apkSize <= 0) return '';
    final mb = apkSize / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}
