import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Video YouTube tối giản dùng cho bảng tin và trình phát của app.
class YouTubeVideo {
  final String id;
  final String title;
  final String author;
  final String thumbnail;
  final String publishedText;
  final String viewsText;
  final Duration? duration;

  const YouTubeVideo({
    required this.id,
    required this.title,
    this.author = '',
    this.thumbnail = '',
    this.publishedText = '',
    this.viewsText = '',
    this.duration,
  });

  String get durationLabel {
    final d = duration;
    if (d == null) return '';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  bool operator ==(Object other) => other is YouTubeVideo && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Nguồn YouTube cho tab "YouTube":
/// - Bảng tin lấy từ trang kết quả tìm kiếm của YouTube (`ytInitialData`) —
///   không cần API key, không phụ thuộc danh sách kênh do chủ app duyệt.
/// - Phát trực tiếp bằng youtube_explode_dart (không iframe/webview)
///   → không có quảng cáo, ưu tiên luồng muxed ≤720p cho máy yếu.
class YouTubeService {
  static YoutubeExplode? _yt;
  static YoutubeExplode get _client => _yt ??= YoutubeExplode();

  static const _ua =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36';

  static const _cacheTtl = Duration(minutes: 10);
  static final Map<String, _FeedCache> _cache = {};
  static final Map<String, Future<List<YouTubeVideo>>> _inFlight = {};

  /// Lấy bảng tin video theo từ khóa. Có cache 10 phút + gộp request trùng.
  static Future<List<YouTubeVideo>> fetchFeed(String query,
      {bool force = false}) async {
    final q = query.trim().isEmpty ? 'việt nam hôm nay' : query.trim();
    final cached = _cache[q];
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.at) < _cacheTtl) {
      return cached.videos;
    }
    final running = _inFlight[q];
    if (running != null) return running;

    // Dùng block body: nếu trả về chính Future đang chờ, whenComplete sẽ
    // tạo vòng chờ vô hạn và bảng tin không bao giờ tải xong.
    final future = _fetchFeed(q).whenComplete(() {
      _inFlight.remove(q);
    });
    _inFlight[q] = future;
    final videos = await future;
    _cache[q] = _FeedCache(videos, DateTime.now());
    return videos;
  }

  static Future<List<YouTubeVideo>> _fetchFeed(String query) async {
    final uri = Uri.https('www.youtube.com', '/results', {
      'search_query': query,
      'hl': 'vi',
      'gl': 'VN',
    });
    final resp = await http.get(uri, headers: {
      'User-Agent': _ua,
      'Accept-Language': 'vi-VN,vi;q=0.9,en;q=0.6',
    }).timeout(const Duration(seconds: 20));

    if (resp.statusCode != 200) {
      throw YouTubeSourceException(
          'YouTube trả HTTP ${resp.statusCode}. Vui lòng thử lại.');
    }
    final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
    final data = extractInitialData(html);
    if (data == null) {
      throw YouTubeSourceException(
          'Không đọc được dữ liệu YouTube. Vui lòng thử lại sau.');
    }
    final videos = parseSearchData(data, limit: 30);
    if (videos.isEmpty) {
      throw YouTubeSourceException(
          'Không tìm thấy video cho "$query". Hãy thử từ khóa khác.');
    }
    return videos;
  }

  /// Tách object `ytInitialData` khỏi HTML bằng cách đếm ngoặc (an toàn với
  /// chuỗi JSON có dấu ngoặc bên trong). Trả null nếu trang không có dữ liệu.
  static Map<String, dynamic>? extractInitialData(String html) {
    final marker = RegExp(r'ytInitialData\s*=\s*');
    final match = marker.firstMatch(html);
    if (match == null) return null;
    final start = html.indexOf('{', match.end);
    if (start < 0) return null;
    final jsonText = _balancedObject(html, start);
    if (jsonText == null) return null;
    try {
      final decoded = jsonDecode(jsonText);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Duyệt đệ quy `ytInitialData`, gom mọi `videoRenderer` thành video.
  static List<YouTubeVideo> parseSearchData(
    Map<String, dynamic> data, {
    int limit = 30,
  }) {
    final out = <YouTubeVideo>[];
    final seen = <String>{};

    void walk(dynamic node) {
      if (out.length >= limit) return;
      if (node is Map) {
        final renderer = node['videoRenderer'];
        if (renderer is Map<String, dynamic>) {
          final video = _videoFromRenderer(renderer);
          if (video != null && seen.add(video.id)) out.add(video);
        }
        for (final value in node.values) {
          walk(value);
          if (out.length >= limit) return;
        }
      } else if (node is List) {
        for (final value in node) {
          walk(value);
          if (out.length >= limit) return;
        }
      }
    }

    walk(data);
    return out;
  }

  static YouTubeVideo? _videoFromRenderer(Map<String, dynamic> r) {
    final id = (r['videoId'] as String?)?.trim() ?? '';
    if (id.isEmpty) return null;

    // Bỏ video livestream: trình phát dùng luồng muxed VOD, live dễ lỗi.
    if (r['isLiveNow'] == true) return null;
    final length = _text(r['lengthText']);
    if (length.isEmpty) return null;

    final title = _runsText(r['title']);
    if (title.isEmpty) return null;

    final author = _runsText(r['ownerText']).isNotEmpty
        ? _runsText(r['ownerText'])
        : _runsText(r['longBylineText']);

    var thumb = '';
    final thumbs = r['thumbnail'] is Map
        ? (r['thumbnail'] as Map)['thumbnails']
        : null;
    if (thumbs is List && thumbs.isNotEmpty) {
      final last = thumbs.last;
      if (last is Map) thumb = (last['url'] as String?) ?? '';
    }
    if (thumb.startsWith('//')) thumb = 'https:$thumb';
    if (thumb.isEmpty) thumb = 'https://i.ytimg.com/vi/$id/hqdefault.jpg';

    return YouTubeVideo(
      id: id,
      title: _unescape(title),
      author: _unescape(author),
      thumbnail: thumb,
      publishedText: _text(r['publishedTimeText']),
      viewsText: _text(r['viewCountText']),
      duration: parseDuration(length),
    );
  }

  /// "1:02:03" / "12:34" → Duration; trả null nếu không hợp lệ.
  static Duration? parseDuration(String text) {
    final parts = text.trim().split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    final nums = <int>[];
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0) return null;
      nums.add(n);
    }
    if (nums.length == 2) return Duration(minutes: nums[0], seconds: nums[1]);
    return Duration(hours: nums[0], minutes: nums[1], seconds: nums[2]);
  }

  /// Trả về URL phát trực tiếp không quảng cáo của 1 video.
  static Future<String?> resolveStreamUrl(String videoId) async {
    try {
      final manifest =
          await _client.videos.streamsClient.getManifest(VideoId(videoId));
      final muxed = manifest.muxed.toList()
        ..sort((a, b) =>
            b.videoResolution.height.compareTo(a.videoResolution.height));
      if (muxed.isEmpty) return null;
      for (final s in muxed) {
        if (s.videoResolution.height <= 720) return s.url.toString();
      }
      return muxed.last.url.toString();
    } catch (e) {
      throw YouTubeSourceException('Không lấy được luồng phát: $e');
    }
  }

  static String _text(dynamic node) {
    if (node is! Map) return '';
    final simple = node['simpleText'];
    if (simple is String) return simple.trim();
    return _runsText(node);
  }

  static String _runsText(dynamic node) {
    if (node is! Map) return '';
    final runs = node['runs'];
    if (runs is List) {
      final b = StringBuffer();
      for (final run in runs) {
        if (run is Map && run['text'] is String) b.write(run['text']);
      }
      return b.toString().trim();
    }
    final simple = node['simpleText'];
    return simple is String ? simple.trim() : '';
  }

  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");

  /// Trả về chuỗi con từ `start` ({) đến ngoặc đóng tương ứng.
  static String? _balancedObject(String text, int start) {
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < text.length; i++) {
      final ch = text[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == '\\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
      } else if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) return text.substring(start, i + 1);
      }
    }
    return null;
  }

  static void clearCache() {
    _cache.clear();
    _inFlight.clear();
  }

  static void close() {
    _yt?.close();
    _yt = null;
  }
}

class _FeedCache {
  final List<YouTubeVideo> videos;
  final DateTime at;
  _FeedCache(this.videos, this.at);
}

/// Xử lý lỗi nguồn YouTube để hiện thông báo thân thiện.
class YouTubeSourceException implements Exception {
  final String message;
  YouTubeSourceException(this.message);
  @override
  String toString() => message;
}
