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

  static final Map<String, _FeedCache> _uploadCache = {};
  static final Map<String, Future<List<YouTubeVideo>>> _uploadInFlight = {};

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

  /// Lấy danh sách video mới nhất của một kênh qua Innertube (browse) — không
  /// cần API key riêng và không phụ thuộc RSS (YouTube trả 404 với nhiều kênh).
  ///
  /// Dùng cho nguồn phim thuyết minh/lồng tiếng: kênh chính thức cập nhật
  /// video mới thì tab Phim tự có nội dung mới, không cần phát hành app.
  static Future<List<YouTubeVideo>> fetchChannelUploads(
    String channelId, {
    bool force = false,
    int limit = 20,
  }) async {
    final key = '$channelId:$limit';
    final cached = _uploadCache[key];
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.at) < _cacheTtl) {
      return cached.videos;
    }
    final running = _uploadInFlight[key];
    if (running != null) return running;

    final future = _fetchChannelUploads(channelId, limit).whenComplete(() {
      _uploadInFlight.remove(key);
    });
    _uploadInFlight[key] = future;
    final videos = await future;
    _uploadCache[key] = _FeedCache(videos, DateTime.now());
    return videos;
  }

  static Future<List<YouTubeVideo>> _fetchChannelUploads(
    String channelId,
    int limit,
  ) async {
    // 1) Innertube browse: JSON nhỏ hơn trang HTML, ổn định hơn RSS.
    try {
      final videos = await _fetchViaBrowse(channelId, limit);
      if (videos.isNotEmpty) return videos;
    } catch (_) {}

    // 2) Trang /videos: cùng cấu trúc lockupViewModel.
    try {
      final videos = await _fetchViaChannelPage(channelId, limit);
      if (videos.isNotEmpty) return videos;
    } catch (_) {}

    throw YouTubeSourceException(
        'Kênh phim chưa có video công khai hoặc YouTube đang chặn. '
        'Vui lòng thử lại sau.');
  }

  static const _browseParams = 'EgZ2aWRlb3PyBgQKAjoA';
  static const _innertubeKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';
  static const _clientVersion = '2.20241126.00.00';

  static Future<List<YouTubeVideo>> _fetchViaBrowse(
    String channelId,
    int limit,
  ) async {
    final resp = await http
        .post(
          Uri.https('www.youtube.com', '/youtubei/v1/browse', {
            'key': _innertubeKey,
            'prettyPrint': 'false',
          }),
          headers: {
            'Content-Type': 'application/json; charset=UTF-8',
            'User-Agent': _ua,
            'Accept-Language': 'vi-VN,vi;q=0.9,en;q=0.6',
          },
          body: jsonEncode({
            'context': {
              'client': {
                'clientName': 'WEB',
                'clientVersion': _clientVersion,
                'hl': 'vi',
                'gl': 'VN',
              },
            },
            'browseId': channelId,
            'params': _browseParams,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw YouTubeSourceException('YouTube trả HTTP ${resp.statusCode}.');
    }
    final decoded =
        jsonDecode(utf8.decode(resp.bodyBytes, allowMalformed: true));
    if (decoded is! Map<String, dynamic>) return const [];
    return parseLockupViewModels(decoded, limit: limit);
  }

  static Future<List<YouTubeVideo>> _fetchViaChannelPage(
    String channelId,
    int limit,
  ) async {
    final resp = await http.get(
      Uri.https('www.youtube.com', '/channel/$channelId/videos'),
      headers: {
        'User-Agent': _ua,
        'Accept-Language': 'vi-VN,vi;q=0.9,en;q=0.6',
      },
    ).timeout(const Duration(seconds: 20));
    if (resp.statusCode != 200) {
      throw YouTubeSourceException('YouTube trả HTTP ${resp.statusCode}.');
    }
    final html = utf8.decode(resp.bodyBytes, allowMalformed: true);
    final data = extractInitialData(html);
    if (data == null) return const [];
    return parseLockupViewModels(data, limit: limit);
  }

  /// Gom `lockupViewModel` (giao diện kênh mới của YouTube) thành video.
  static List<YouTubeVideo> parseLockupViewModels(
    Object? root, {
    int limit = 20,
  }) {
    final out = <YouTubeVideo>[];
    final seen = <String>{};

    void walk(Object? node) {
      if (out.length >= limit) return;
      if (node is Map) {
        final lock = node['lockupViewModel'];
        if (lock is Map) {
          final video = _videoFromLockup(lock);
          if (video != null && seen.add(video.id)) out.add(video);
        }
        for (final value in node.values) {
          walk(value);
        }
      } else if (node is List) {
        for (final value in node) {
          walk(value);
        }
      }
    }

    walk(root);
    return out;
  }

  static YouTubeVideo? _videoFromLockup(Map<dynamic, dynamic> lock) {
    final type = lock['contentType'];
    if (type is String && type != 'LOCKUP_CONTENT_TYPE_VIDEO') return null;

    final id = (lock['contentId'] as String?)?.trim() ?? '';
    if (id.isEmpty) return null;

    final meta = lock['metadata']?['lockupMetadataViewModel'];
    if (meta is! Map) return null;
    final title =
        ((meta['title'] as Map?)?['content'] as String?)?.trim() ?? '';
    if (title.isEmpty) return null;

    var viewsText = '';
    var publishedText = '';
    final rows = meta['metadata']?['contentMetadataViewModel']?['metadataRows'];
    if (rows is List) {
      final parts = <Map>[];
      for (final row in rows) {
        final p = row is Map ? row['metadataParts'] : null;
        if (p is List) parts.addAll(p.whereType<Map>());
      }
      for (final part in parts) {
        final text = ((part['text'] as Map?)?['content'] as String?)?.trim();
        if (text == null || text.isEmpty) continue;
        final a11y = (part['accessibilityLabel'] as String?)?.trim() ?? '';
        final lower = text.toLowerCase();
        final looksLikeViews = lower.contains('lượt xem') ||
            lower.contains('views') ||
            RegExp(r'^[\d.,]+\s*[nmkbt]?$').hasMatch(lower);
        if (viewsText.isEmpty && looksLikeViews) {
          viewsText = a11y.isNotEmpty && a11y.toLowerCase().contains('lượt xem')
              ? a11y
              : (lower.contains('lượt xem') || lower.contains('views')
                  ? text
                  : '$text lượt xem');
        } else if (publishedText.isEmpty) {
          publishedText = a11y.isNotEmpty ? a11y : text;
        }
      }
    }

    Duration? duration;
    final overlays = lock['contentImage']?['thumbnailViewModel']?['overlays'];
    if (overlays is List) {
      for (final overlay in overlays) {
        final badge = _findDurationBadge(overlay);
        if (badge != null) {
          duration = parseDuration(badge);
          if (duration != null) break;
        }
      }
    }

    return YouTubeVideo(
      id: id,
      title: title,
      author: '',
      thumbnail: 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
      publishedText: publishedText,
      viewsText: viewsText,
      duration: duration,
    );
  }

  static String? _findDurationBadge(Object? node) {
    if (node is Map) {
      final badge = node['thumbnailBadgeViewModel'];
      if (badge is Map) {
        final text = (badge['text'] as String?)?.trim() ?? '';
        if (RegExp(r'^\d{1,2}:\d{2}(:\d{2})?$').hasMatch(text)) return text;
      }
      for (final value in node.values) {
        final found = _findDurationBadge(value);
        if (found != null) return found;
      }
    } else if (node is List) {
      for (final value in node) {
        final found = _findDurationBadge(value);
        if (found != null) return found;
      }
    }
    return null;
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

  static String _unescape(String s) {
    var out = s
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'");
    out = out.replaceAllMapped(
      RegExp(r'&#(x?[0-9a-fA-F]+);'),
      (m) {
        final raw = m.group(1) ?? '';
        final code = raw.startsWith('x') || raw.startsWith('X')
            ? int.tryParse(raw.substring(1), radix: 16)
            : int.tryParse(raw);
        return code == null ? m.group(0)! : String.fromCharCode(code);
      },
    );
    return out;
  }

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
    _uploadCache.clear();
    _uploadInFlight.clear();
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
