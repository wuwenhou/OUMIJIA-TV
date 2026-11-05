// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

import 'package:oumijia_tv/services/youtube_service.dart';

/// Đọc trang `/videos` của một kênh YouTube, liệt kê video + thời lượng.
/// Chạy: `dart run tool/channel_probe.dart <url>`
Future<void> main(List<String> args) async {
  final url = args.isEmpty
      ? 'https://www.youtube.com/@iQIYIPhimTM/videos'
      : args.first;
  final client = HttpClient();
  final req = await client.getUrl(Uri.parse(url));
  req.headers.set('User-Agent',
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/155.0.0.0 Safari/537.36');
  req.headers.set('Accept-Language', 'vi-VN,vi;q=0.9,en;q=0.6');
  final resp = await req.close();
  final html = await resp.transform(utf8.decoder).join();
  print('HTTP ${resp.statusCode} html=${html.length}');
  final data = YouTubeService.extractInitialData(html);
  if (data == null) {
    print('NO ytInitialData');
    return;
  }
  final videos = YouTubeService.parseSearchData(data, limit: 30);
  print('videos=${videos.length}');
  for (final v in videos) {
    print('${v.id} | ${v.durationLabel} | ${v.author} | ${v.title}');
  }
  // metadata kênh
  final meta = data['metadata']?['channelMetadataRenderer'];
  if (meta is Map) {
    print('channel=${meta['title']} id=${meta['externalId']}');
  }
  client.close();
}
