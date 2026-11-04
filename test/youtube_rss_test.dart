import 'package:flutter_test/flutter_test.dart';

import 'package:oumijia_tv/services/youtube_service.dart';

/// Bảng tin YouTube: đọc `ytInitialData`, gom `videoRenderer`, bỏ livestream,
/// chuẩn hoá thời lượng và tránh trùng video.
void main() {
  Map<String, dynamic> renderer({
    required String id,
    required String title,
    String author = 'Kênh thử',
    String length = '12:34',
    String views = '1.234 lượt xem',
    String published = '2 giờ trước',
    bool live = false,
    String thumb = '//i.ytimg.com/vi/abc/hqdefault.jpg',
  }) =>
      {
        'videoId': id,
        'title': {
          'runs': [
            {'text': title},
          ],
        },
        'ownerText': {
          'runs': [
            {'text': author},
          ],
        },
        'lengthText': {'simpleText': length},
        'viewCountText': {'simpleText': views},
        'publishedTimeText': {'simpleText': published},
        'isLiveNow': live,
        'thumbnail': {
          'thumbnails': [
            {'url': 'https://i.ytimg.com/vi/$id/default.jpg'},
            {'url': thumb},
          ],
        },
      };

  test('gom videoRenderer, đọc đủ trường và bỏ video trùng', () {
    final data = <String, dynamic>{
      'contents': {
        'section': {
          'items': [
            {'videoRenderer': renderer(id: 'abc123def45', title: 'Tin & sự kiện')},
            {'videoRenderer': renderer(id: 'abc123def45', title: 'Bản trùng')},
            {'videoRenderer': renderer(id: 'xyz987uvw65', title: 'Video hai')},
          ],
        },
      },
    };

    final videos = YouTubeService.parseSearchData(data, limit: 10);
    expect(videos.length, 2);
    expect(videos[0].id, 'abc123def45');
    expect(videos[0].title, 'Tin & sự kiện');
    expect(videos[0].author, 'Kênh thử');
    expect(videos[0].viewsText, '1.234 lượt xem');
    expect(videos[0].publishedText, '2 giờ trước');
    expect(videos[0].durationLabel, '12:34');
    expect(videos[0].thumbnail, 'https://i.ytimg.com/vi/abc/hqdefault.jpg');
    expect(videos[1].id, 'xyz987uvw65');
  });

  test('bỏ livestream và video thiếu thời lượng; tôn trọng limit', () {
    final data = <String, dynamic>{
      'items': [
        {'videoRenderer': renderer(id: 'live0000001', title: 'Live', live: true)},
        {
          'videoRenderer': {
            'videoId': 'nolength001',
            'title': {
              'runs': [
                {'text': 'Không có độ dài'}
              ]
            }
          }
        },
        {'videoRenderer': renderer(id: 'ok000000001', title: 'OK 1')},
        {'videoRenderer': renderer(id: 'ok000000002', title: 'OK 2')},
      ],
    };

    final videos = YouTubeService.parseSearchData(data, limit: 1);
    expect(videos.length, 1);
    expect(videos.single.id, 'ok000000001');
  });

  test('tách ytInitialData bằng đếm ngoặc, không nhầm ngoặc trong chuỗi', () {
    const html = '<script>var ytInitialData = '
        '{"a":{"b":"}","c":[1,2]},"d":"x"};</script>';
    final data = YouTubeService.extractInitialData(html);
    expect(data, isNotNull);
    expect((data!['a'] as Map)['b'], '}');
    expect(data['d'], 'x');

    expect(YouTubeService.extractInitialData('<html></html>'), isNull);
    expect(YouTubeService.extractInitialData('ytInitialData = {broken;'), isNull);
  });

  test('parse thời lượng mm:ss và hh:mm:ss', () {
    expect(YouTubeService.parseDuration('12:34'),
        const Duration(minutes: 12, seconds: 34));
    expect(YouTubeService.parseDuration('1:02:03'),
        const Duration(hours: 1, minutes: 2, seconds: 3));
    expect(YouTubeService.parseDuration('Streamed'), isNull);
    expect(YouTubeService.parseDuration(''), isNull);
  });
}
