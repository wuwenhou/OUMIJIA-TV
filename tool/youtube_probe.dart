// ignore_for_file: avoid_print
import 'package:oumijia_tv/services/youtube_service.dart';

/// Kiểm tra nhanh khả năng lấy bảng tin + luồng phát YouTube của app.
/// Chạy: `dart run tool/youtube_probe.dart "tin tức việt nam"`
/// hoặc: `dart run tool/youtube_probe.dart --video <videoId>`
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Cần truyền từ khóa hoặc --video <id>');
    return;
  }
  if (args.first == '--video' && args.length > 1) {
    try {
      final url = await YouTubeService.resolveStreamUrl(args[1]);
      print('video=${args[1]} stream=${url == null ? 'NULL' : 'OK'}');
    } catch (e) {
      print('video=${args[1]} ERROR: $e');
    }
    YouTubeService.close();
    return;
  }
  final query = args.join(' ');
  try {
    final videos = await YouTubeService.fetchFeed(query, force: true);
    print('query=$query videos=${videos.length}');
    for (final v in videos.take(5)) {
      print('${v.id} | ${v.title} | ${v.author} | ${v.durationLabel}');
    }
    if (videos.isNotEmpty) {
      final url = await YouTubeService.resolveStreamUrl(videos.first.id);
      print('stream=${url == null ? 'NULL' : 'OK'}');
    }
  } catch (e) {
    print('ERROR: $e');
  }
  YouTubeService.close();
}
