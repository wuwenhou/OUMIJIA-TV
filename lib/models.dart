/// Mô hình dữ liệu OUMIJIA TV.
/// Toàn bộ nội dung lấy từ file cấu hình JSON (assets + GitHub).
library;

class Channel {
  final String id;
  final String name;
  final String group;
  final String logo;
  final String primary;
  final List<String> fallback;

  Channel({
    required this.id,
    required this.name,
    required this.group,
    required this.logo,
    required this.primary,
    this.fallback = const [],
  });

  factory Channel.fromJson(Map<String, dynamic> j) => Channel(
        id: j['id'] as String,
        name: j['name'] as String,
        group: (j['group'] as String?) ?? 'Truyền hình',
        logo: (j['logo'] as String?) ?? '',
        primary: j['primary'] as String,
        fallback: (j['fallback'] as List<dynamic>? ?? [])
            .map((e) => e as String)
            .toList(),
      );

  /// Danh sách tất cả URL thử lần lượt khi phát lỗi.
  List<String> get allUrls => [primary, ...fallback];
}

class YouTubeCategory {
  final String id;
  final String name;
  final String icon;
  final List<YouTubeChannel> channels;

  YouTubeCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.channels,
  });

  factory YouTubeCategory.fromJson(Map<String, dynamic> j) => YouTubeCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        icon: (j['icon'] as String?) ?? '🎵',
        channels: (j['channels'] as List<dynamic>? ?? [])
            .map((e) => YouTubeChannel.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class YouTubeChannel {
  final String name;
  final String channelId; // UCxxxx của kênh YouTube
  final String note;

  YouTubeChannel({required this.name, required this.channelId, this.note = ''});

  factory YouTubeChannel.fromJson(Map<String, dynamic> j) => YouTubeChannel(
        name: j['name'] as String,
        channelId: (j['channelId'] ?? j['channel_id'] ?? '') as String,
        note: (j['note'] as String?) ?? '',
      );
}

class MovieItem {
  final String id;
  final String title;
  final String poster;
  final String url;
  final String group;
  final String note;

  MovieItem({
    required this.id,
    required this.title,
    required this.poster,
    required this.url,
    this.group = 'Phim',
    this.note = '',
  });

  factory MovieItem.fromJson(Map<String, dynamic> j) => MovieItem(
        id: j['id'] as String,
        title: j['title'] as String,
        poster: (j['poster'] as String?) ?? '',
        url: j['url'] as String,
        group: (j['group'] as String?) ?? 'Phim',
        note: (j['note'] as String?) ?? '',
      );
}

class AppConfig {
  final List<Channel> channels;
  final List<YouTubeCategory> youtubeCategories;
  final List<MovieItem> movies;
  final String source; // 'remote' hoặc 'bundled'

  AppConfig({
    required this.channels,
    required this.youtubeCategories,
    required this.movies,
    this.source = 'bundled',
  });

  factory AppConfig.fromJson(Map<String, dynamic> j, {String source = 'remote'}) =>
      AppConfig(
        channels: (j['channels'] as List<dynamic>? ?? [])
            .map((e) => Channel.fromJson(e as Map<String, dynamic>))
            .toList(),
        youtubeCategories: (j['youtubeCategories'] as List<dynamic>? ?? [])
            .map((e) => YouTubeCategory.fromJson(e as Map<String, dynamic>))
            .toList(),
        movies: (j['movies'] as List<dynamic>? ?? [])
            .map((e) => MovieItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        source: source,
      );

  /// Tìm kênh theo tên (dùng cho lệnh giọng nói "bật vtv3").
  Channel? findChannelByName(String query) {
    final q = _normalize(query);
    for (final c in channels) {
      if (q.contains(_normalize(c.name))) return c;
      // "vtv3" khớp "VTV3 HD"
      final idNoDash = c.id.replaceAll('-', '');
      if (q.contains(_normalize(idNoDash))) return c;
    }
    return null;
  }

  /// Tìm danh mục YouTube theo tên ("mở nhạc trữ tình").
  /// Khớp lỏng: nếu MỘT từ đáng kể trong tên danh mục xuất hiện trong câu.
  YouTubeCategory? findCategoryByName(String query) {
    final q = _normalize(query);
    for (final c in youtubeCategories) {
      if (q.contains(_normalize(c.name))) return c;
      // Khớp từng từ: "nhạc trữ tình" → khớp "Ca nhạc" qua từ "nhạc"
      final words = _normalize(c.name).split(' ');
      final significant = words.where((w) => w.length >= 2 && !_stopWords.contains(w));
      for (final w in significant) {
        if (q.contains(w)) return c;
      }
    }
    return null;
  }

  /// Từ yếu nghĩa không dùng để khớp danh mục.
  static const _stopWords = {'ca', 'của', 'và'};

  static String _normalize(String s) {
    var t = s.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    // Bỏ dấu tiếng Việt: "nhạc" → "nhac"
    const src = 'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
    const dst = 'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
    for (var i = 0; i < src.length; i++) {
      t = t.replaceAll(src[i], dst[i]);
    }
    return t;
  }
}
