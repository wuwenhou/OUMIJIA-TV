import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
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

  static String friendlyDownloadError(Object error) {
    final message = error.toString();
    if (message.contains('HTTP 504') ||
        message.contains('HTTP 503') ||
        message.contains('HTTP 502')) {
      return 'Máy chủ GitHub đang quá tải. Vui lòng thử lại sau vài phút.';
    }
    if (message.contains('HandshakeException') ||
        message.contains('SocketException') ||
        message.contains('TimeoutException')) {
      return 'Không có kết nối ổn định đến GitHub. Vui lòng thử lại.';
    }
    if (message.contains('HTTP')) return 'Tải bản cập nhật thất bại.';
    return 'Tải bản cập nhật thất bại. Vui lòng thử lại.';
  }

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

      final digestRaw = (apkAsset['digest'] as String?) ?? '';
      final sha256Hex = digestRaw.startsWith('sha256:')
          ? digestRaw.substring('sha256:'.length)
          : '';

      return UpdateInfo(
        version: version,
        tagName: tag,
        apkUrl: apkAsset['browser_download_url'] as String,
        apkApiUrl: (apkAsset['url'] as String?) ?? '',
        apkSize: (apkAsset['size'] as num?)?.toInt() ?? 0,
        releaseNotes: (json['body'] as String?) ?? '',
        sha256: sha256Hex,
      );
    } catch (_) {
      return null;
    }
  }

  /// Tải APK về thư mục cache, gọi onProgress(0..1).
  ///
  /// GitHub đôi khi trả 502/503/504 cho `browser_download_url`; endpoint API
  /// của asset với Accept: application/octet-stream ổn định hơn nên thử trước,
  /// rồi mới fallback sang link tải trực tiếp. Mỗi đường tải được thử tối đa
  /// 3 lần với délai tăng dần khi server tạm quá tải.
  static Future<File> downloadApk(
    UpdateInfo info, {
    void Function(double progress)? onProgress,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/OUMIJIA-TV-${info.version}.apk');

    final candidates = <String>[
      if (info.apkApiUrl.isNotEmpty) info.apkApiUrl,
      info.apkUrl,
    ];

    Object? lastError;
    for (final url in candidates) {
      for (var attempt = 1; attempt <= 3; attempt++) {
        final client = http.Client();
        try {
          final req = http.Request('GET', Uri.parse(url))
            ..headers['Accept'] = 'application/octet-stream'
            ..headers['User-Agent'] =
                'Mozilla/5.0 (Linux; Android 16) AppleWebKit/537.36 Chrome/155.0.0.0 Mobile Safari/537.36'
            ..followRedirects = true
            ..maxRedirects = 10;

          final resp = await client.send(req).timeout(const Duration(seconds: 60));
          final status = resp.statusCode;
          if (status != 200) {
            // Drain response để giữ keep-alive ổn định khi thử lại.
            await resp.stream.drain<void>();
            lastError = Exception('HTTP $status');
            if ((status == 502 || status == 503 || status == 504) &&
                attempt < 3) {
              await Future<void>.delayed(Duration(seconds: 2 * attempt));
              continue;
            }
            break;
          }

          final total = resp.contentLength ?? info.apkSize;
          final sink = file.openWrite();
          final digestSink = _DigestSink();
          final hasher = sha256.startChunkedConversion(digestSink);
          int received = 0;
          await for (final chunk in resp.stream) {
            sink.add(chunk);
            hasher.add(chunk);
            received += chunk.length;
            if (total > 0 && onProgress != null) {
              onProgress(received / total);
            }
          }
          await sink.close();
          hasher.close();

          // ---- kiểm tra toàn vẹn ----
          if (info.apkSize > 0 && received != info.apkSize) {
            await file.delete();
            throw Exception('Gói tải không đầy đủ ($received/${info.apkSize} byte)');
          }
          if (info.sha256.isNotEmpty &&
              digestSink.value?.toString() != info.sha256.toLowerCase()) {
            await file.delete();
            throw Exception('Sai mã SHA-256 — gói tải không toàn vẹn');
          }
          if (await file.length() < 2) {
            await file.delete();
            throw Exception('File tải về rỗng hoặc quá nhỏ');
          }
          final head = await file.openRead(0, 2).first;
          if (head.length < 2 || head[0] != 0x50 || head[1] != 0x4B) {
            await file.delete();
            throw Exception('File tải về không phải APK hợp lệ');
          }

          // Chữ ký APK do Android kiểm tra khi cài: nếu APK không cùng chứng chỉ
          // với bản đang cài, hệ thống sẽ từ chối — app không thể bỏ qua bước này.
          return file;
        } catch (e) {
          lastError = e;
          // Lỗi mạng tạm thời thì thử lại.
          final message = e.toString();
          if ((message.contains('HandshakeException') ||
                  message.contains('SocketException') ||
                  message.contains('TimeoutException')) &&
              attempt < 3) {
            await Future<void>.delayed(Duration(seconds: 2 * attempt));
            continue;
          }
        } finally {
          client.close();
        }
      }
    }

    throw lastError ?? Exception('Không tải được bản cập nhật.');
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
  final String apkApiUrl;
  final int apkSize;
  final String releaseNotes;

  /// SHA-256 của APK do GitHub cung cấp (rỗng nếu release cũ không có).
  final String sha256;

  UpdateInfo({
    required this.version,
    required this.tagName,
    required this.apkUrl,
    this.apkApiUrl = '',
    required this.apkSize,
    required this.releaseNotes,
    this.sha256 = '',
  });

  String get sizeText {
    if (apkSize <= 0) return '';
    final mb = apkSize / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

/// Sink nhận Digest cuối cùng từ hash chunked của package:crypto.
class _DigestSink implements Sink<Digest> {
  Digest? value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
