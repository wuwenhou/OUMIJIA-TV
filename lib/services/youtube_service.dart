import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Video YouTube tối giản dùng cho playlist của app.
class YouTubeVideo {
  final String id;
  final String title;
  final DateTime? published;

  const YouTubeVideo({required this.id, required this.title, this.published});

  @override
  bool operator ==(Object other) => other is YouTubeVideo && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Phát YouTube KHÔNG quảng cáo:
/// - Danh sách video lấy từ RSS chính thức của kênh
///   (`youtube.com/feeds/videos.xml`) — ổn định, không cần API key.
/// - Luồng phát trích trực tiếp bằng youtube_explode_dart (không iframe/webview)
///   → không có quảng cáo, ưu tiên luồng muxed ≤720p cho máy yếu.
class YouTubeService {
  static YoutubeExplode? _yt;

  static YoutubeExplode get _client => _yt ??= YoutubeExplode();

  static const _ua =
      'Mozilla/5.0 (Linux; Android 16; Pixel 10) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/155.0.0.0 Mobile Safari/537.36';

  /// Lấy video mới nhất của 1 kênh qua RSS (tối đa ~15 video/lần).
  static Future<List<YouTubeVideo>> channelVideos(String channelId,
      {int limit = 20}) async {
    final resp = await http
        .get(
          Uri.parse(
              'https://www.youtube.com/feeds/videos.xml?channel_id=$channelId'),
          headers: {'User-Agent': _ua},
        )
        .timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw YouTubeSourceException('RSS YouTube trả HTTP ${resp.statusCode}');
    }
    return parseRss(utf8.decode(resp.bodyBytes), limit: limit);
  }

  /// Phân tích RSS YouTube (tách riêng để test được).
  static List<YouTubeVideo> parseRss(String body, {int limit = 20}) {
    final videos = <YouTubeVideo>[];
    final entries = RegExp(r'<entry>(.*?)</entry>', dotAll: true);
    for (final m in entries.allMatches(body)) {
      final entry = m.group(1) ?? '';
      final id = _first(entry, r'<yt:videoId>([^<]+)</yt:videoId>');
      if (id.isEmpty) continue;
      final title = _unescape(
        _first(entry, r'<media:title>([^<]*)</media:title>',
            fallback: r'<title>([^<]*)</title>'),
      );
      final pub =
          DateTime.tryParse(_first(entry, r'<published>([^<]+)</published>'));
      videos.add(YouTubeVideo(id: id, title: title, published: pub));
      if (videos.length >= limit) break;
    }
    return videos;
  }

  /// Trả về URL phát trực tiếp không quảng cáo của 1 video.
  static Future<String?> resolveStreamUrl(String videoId) async {
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
  }

  /// Tiêu đề video (nếu cần lấy lẻ).
  static Future<String> videoTitle(String videoId) async {
    try {
      final v = await _client.videos.get(VideoId(videoId));
      return v.title;
    } catch (_) {
      return '';
    }
  }

  static String _first(String text, String pattern, {String? fallback}) {
    final m = RegExp(pattern, dotAll: true).firstMatch(text);
    if (m != null) return m.group(1)?.trim() ?? '';
    if (fallback != null) {
      final f = RegExp(fallback, dotAll: true).firstMatch(text);
      return f?.group(1)?.trim() ?? '';
    }
    return '';
  }

  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");

  static void close() {
    _yt?.close();
    _yt = null;
  }
}

/// Xử lý lỗi nguồn YouTube để hiện thông báo thân thiện.
class YouTubeSourceException implements Exception {
  final String message;
  YouTubeSourceException(this.message);
  @override
  String toString() => message;
}

/// Phát liên tục 1 danh sách video: hết bài tự chuyển bài sau, lỗi tự nhảy bài.
class ContinuousPlaylist {
  final List<YouTubeVideo> videos;
  int index = 0;

  ContinuousPlaylist(this.videos);

  YouTubeVideo? get current => videos.isEmpty ? null : videos[index];

  bool get canNext => index < videos.length - 1;

  bool get canPrev => index > 0;

  void next() {
    if (canNext) index++;
  }

  void prev() {
    if (canPrev) index--;
  }

  void skipBroken() {
    if (canNext) {
      index++;
    }
  }
}
