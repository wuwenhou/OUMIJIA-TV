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
  final Map<String, String> headers;

  /// trạng thái kiểm tra thực tế (từ channel health check / cấu hình)
  final String health; // WORKING / DEGRADED / OFFLINE / INVALID / UNVERIFIED
  final String lastVerified; // ISO date, rỗng = chưa kiểm tra

  Channel({
    required this.id,
    required this.name,
    required this.group,
    required this.logo,
    required this.primary,
    this.fallback = const [],
    this.headers = const {},
    this.health = 'UNVERIFIED',
    this.lastVerified = '',
  });

  factory Channel.fromJson(Map<String, dynamic> j,
      {Map<String, String> defaultHeaders = const {}}) {
    final ownHeaders = (j['headers'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, v.toString()));
    return Channel(
      id: j['id'] as String,
      name: j['name'] as String,
      group: (j['group'] as String?) ?? 'Truyền hình',
      logo: (j['logo'] as String?) ?? '',
      primary: j['primary'] as String,
      fallback: (j['fallback'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      headers: {...defaultHeaders, ...ownHeaders},
      health: (j['health'] as String?) ?? 'UNVERIFIED',
      lastVerified: (j['lastVerified'] as String?) ?? '',
    );
  }

  /// Kênh chưa có nguồn phát hợp lệ → không mở được
  bool get unavailable =>
      primary.isEmpty || health == 'OFFLINE' || health == 'INVALID';

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
  final Map<String, String> headers;

  MovieItem({
    required this.id,
    required this.title,
    required this.poster,
    required this.url,
    this.group = 'Phim',
    this.note = '',
    this.headers = const {},
  });

  factory MovieItem.fromJson(Map<String, dynamic> j) => MovieItem(
        id: j['id'] as String,
        title: j['title'] as String,
        poster: (j['poster'] as String?) ?? '',
        url: j['url'] as String,
        group: (j['group'] as String?) ?? 'Phim',
        note: (j['note'] as String?) ?? '',
        headers: (j['headers'] as Map<String, dynamic>? ?? {})
            .map((k, v) => MapEntry(k, v.toString())),
      );
}

/// Nguồn phim động lấy từ kênh YouTube chính thức (RSS công khai).
///
/// Dùng cho các kênh có bản quyền đăng phim thuyết minh/lồng tiếng liên tục:
/// app chỉ đọc danh sách video công khai, không tải lại nội dung.
class MovieSource {
  final String id;
  final String name;
  final String channelId;
  final String note;

  MovieSource({
    required this.id,
    required this.name,
    required this.channelId,
    this.note = '',
  });

  factory MovieSource.fromJson(Map<String, dynamic> j) => MovieSource(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? 'Phim',
        channelId: j['channelId'] as String,
        note: (j['note'] as String?) ?? '',
      );
}

class AppConfig {
  final List<Channel> channels;
  final List<YouTubeCategory> youtubeCategories;
  final List<MovieItem> movies;
  final List<MovieSource> movieSources;
  final String source; // 'remote' hoặc 'bundled'

  AppConfig({
    required this.channels,
    required this.youtubeCategories,
    required this.movies,
    this.movieSources = const [],
    this.source = 'bundled',
  });

  factory AppConfig.fromJson(Map<String, dynamic> j, {String source = 'remote'}) {
    final globalHeaders = (j['headers'] as Map<String, dynamic>? ?? {})
        .map((k, v) => MapEntry(k, v.toString()));
    return AppConfig(
      channels: (j['channels'] as List<dynamic>? ?? [])
          .map((e) => Channel.fromJson(e as Map<String, dynamic>,
              defaultHeaders: globalHeaders))
          .toList(),
      youtubeCategories: (j['youtubeCategories'] as List<dynamic>? ?? [])
          .map((e) => YouTubeCategory.fromJson(e as Map<String, dynamic>))
          .toList(),
      movies: (j['movies'] as List<dynamic>? ?? [])
          .map((e) => MovieItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      movieSources: (j['movieSources'] as List<dynamic>? ?? [])
          .map((e) => MovieSource.fromJson(e as Map<String, dynamic>))
          .toList(),
      source: source,
    );
  }

  /// Tìm kiếm kênh theo từ khóa (bỏ dấu, không phân biệt hoa/thường).
  List<Channel> searchChannels(String query) {
    final q = _normalize(query);
    if (q.isEmpty) return channels;
    return channels
        .where((c) =>
            _normalize(c.name).contains(q) ||
            _normalize(c.group).contains(q) ||
            c.id.replaceAll('-', ' ').contains(q))
        .toList();
  }

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
