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

  Map<String, dynamic> lockup({
    required String id,
    required String title,
    String? views,
    String? viewsA11y,
    String? published,
    String? duration,
    String contentType = 'LOCKUP_CONTENT_TYPE_VIDEO',
  }) =>
      {
        'contentId': id,
        'contentType': contentType,
        'contentImage': {
          'thumbnailViewModel': {
            'overlays': [
              if (duration != null)
                {
                  'thumbnailBottomOverlayViewModel': {
                    'badges': [
                      {
                        'thumbnailBadgeViewModel': {'text': duration},
                      },
                    ],
                  },
                },
            ],
          },
        },
        'metadata': {
          'lockupMetadataViewModel': {
            'title': {'content': title},
            'metadata': {
              'contentMetadataViewModel': {
                'metadataRows': [
                  {
                    'metadataParts': [
                      if (views != null)
                        {
                          'text': {'content': views},
                          'accessibilityLabel': viewsA11y ?? views,
                        },
                      if (published != null)
                        {'text': {'content': published}},
                    ],
                  },
                ],
              },
            },
          },
        },
      };

  test('parse lockupViewModel của kênh: tiêu đề, lượt xem, ngày, thời lượng', () {
    final data = <String, dynamic>{
      'contents': {
        'richGridRenderer': {
          'contents': [
            {
              'richItemRenderer': {
                'content': {
                  'lockupViewModel': lockup(
                    id: 'WlF0LxX_c8Q',
                    title: 'Phim hay tập 7',
                    views: '1.234.567',
                    viewsA11y: '1.234.567 lượt xem',
                    published: '16 giờ trước',
                    duration: '55:46',
                  ),
                },
              },
            },
            // Bản trùng phải bị bỏ.
            {
              'lockupViewModel': lockup(
                id: 'WlF0LxX_c8Q',
                title: 'Bản trùng',
              ),
            },
            // Playlist không phải video phải bị bỏ.
            {
              'lockupViewModel': lockup(
                id: 'PL123456789',
                title: 'Danh sách phát',
                contentType: 'LOCKUP_CONTENT_TYPE_PLAYLIST',
              ),
            },
            {
              'lockupViewModel': lockup(
                id: 'abc123def45',
                title: 'Tập 6',
                published: '2 ngày trước',
              ),
            },
          ],
        },
      },
    };

    final videos = YouTubeService.parseLockupViewModels(data, limit: 10);
    expect(videos.length, 2);

    final first = videos.first;
    expect(first.id, 'WlF0LxX_c8Q');
    expect(first.title, 'Phim hay tập 7');
    expect(first.viewsText, '1.234.567 lượt xem');
    expect(first.publishedText, '16 giờ trước');
    expect(first.durationLabel, '55:46');
    expect(first.thumbnail, 'https://i.ytimg.com/vi/WlF0LxX_c8Q/hqdefault.jpg');

    expect(videos[1].id, 'abc123def45');
    expect(videos[1].durationLabel, '');
  });

  test('parse lockupViewModel tôn trọng limit', () {
    final data = {
      'items': [
        for (var i = 0; i < 5; i++)
          {
            'lockupViewModel': lockup(
              id: 'vid0000000$i',
              title: 'Video $i',
            ),
          },
      ],
    };

    final videos = YouTubeService.parseLockupViewModels(data, limit: 3);
    expect(videos.length, 3);
    expect(videos.map((v) => v.id),
        ['vid00000000', 'vid00000001', 'vid00000002']);
  });

  test('bỏ video sắp công chiếu/premiere khỏi nguồn phim', () {
    final data = {
      'items': [
        {
          'lockupViewModel': lockup(
            id: 'future000001',
            title: 'Tập sắp ra mắt',
            published: '25 giờ nữa',
          ),
        },
        {
          'lockupViewModel': lockup(
            id: 'ok000000001',
            title: 'Tập đã phát',
            published: '2 giờ trước',
          ),
        },
      ],
    };

    final videos = YouTubeService.parseLockupViewModels(data, limit: 10);
    expect(videos.map((v) => v.id), ['ok000000001']);
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
