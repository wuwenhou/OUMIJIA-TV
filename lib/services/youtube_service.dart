import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Phát YouTube KHÔNG quảng cáo:
/// - Trích trực tiếp luồng stream bằng youtube_explode_dart
/// - Không dùng iframe/webview của YouTube → không có quảng cáo
/// - Ưu tiên luồng muxed (có sẵn âm thanh + hình, itag 18/22) để player phát đơn giản
class YouTubeService {
  static YoutubeExplode? _yt;

  static YoutubeExplode get _client => _yt ??= YoutubeExplode();

  /// Lấy danh sách video mới nhất của 1 kênh (dùng cho playlist chạy liên tục).
  static Future<List<Video>> channelVideos(String channelId,
      {int limit = 50}) async {
    final uploads =
        await _client.channels.getUploads(VideoId(channelId)).take(limit).toList();
    return uploads;
  }

  /// Trả về URL phát trực tiếp không quảng cáo của 1 video.
  /// Thử muxed cao nhất trước (22 = 720p, 18 = 360p), rồi tới mọi luồng muxed khác.
  static Future<String?> resolveStreamUrl(VideoId videoId) async {
    final manifest = await _client.videos.streamsClient.getManifest(videoId);
    final muxed = manifest.muxed
        .toList()
      ..sort((a, b) => b.videoResolution.height
          .compareTo(a.videoResolution.height));
    if (muxed.isEmpty) return null;
    // Giới hạn 720p trở xuống cho mượt trên máy yếu
    for (final s in muxed) {
      if (s.videoResolution.height <= 720) return s.url.toString();
    }
    return muxed.last.url.toString();
  }

  /// Tiêu đề video (hiện to trên màn hình khi phát).
  static Future<String> videoTitle(VideoId videoId) async {
    try {
      final v = await _client.videos.get(videoId);
      return v.title;
    } catch (_) {
      return '';
    }
  }

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
  final List<Video> videos;
  int index = 0;

  ContinuousPlaylist(this.videos);

  Video? get current => videos.isEmpty ? null : videos[index];

  bool get canNext => index < videos.length - 1;
  bool get canPrev => index > 0;

  void next() {
    if (canNext) index++;
  }

  void prev() {
    if (canPrev) index--;
  }

  void skipBroken() {
    // Khi bài lỗi: thử bài kế tiếp; nếu hết vòng thì dừng ở cuối
    if (canNext) {
      index++;
    }
  }
}
