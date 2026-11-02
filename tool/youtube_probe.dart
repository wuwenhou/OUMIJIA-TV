// ignore_for_file: avoid_print, unintended_html_in_doc_comment
import 'package:oumijia_tv/services/youtube_service.dart';

/// Kiểm tra nhanh khả năng lấy video + luồng phát YouTube của app.
/// Chạy: `dart run tool/youtube_probe.dart <channelId>` hoặc
/// `dart run tool/youtube_probe.dart --video <videoId>`
/// hoặc: `dart run tool/youtube_probe.dart --video <videoId>`
Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    print('Cần truyền channelId (UC...) hoặc --video <id>');
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
  for (final id in args) {
    try {
      final videos = await YouTubeService.channelVideos(id, limit: 3);
      print('$id | videos=${videos.length}'
          '${videos.isEmpty ? '' : ' | first=${videos.first.title}'}');
      if (videos.isNotEmpty) {
        final url = await YouTubeService.resolveStreamUrl(videos.first.id);
        print('  stream=${url == null ? 'NULL' : 'OK'}');
      }
    } catch (e) {
      print('$id | ERROR: $e');
    }
  }
  YouTubeService.close();
}
