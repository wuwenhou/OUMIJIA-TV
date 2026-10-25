import 'package:flutter_test/flutter_test.dart';

import 'package:oumijia_tv/models.dart';

void main() {
  test('AppConfig tìm kênh theo tên (lệnh giọng nói)', () {
    final config = AppConfig.fromJson({
      'channels': [
        {'id': 'vtv1', 'name': 'VTV1', 'primary': 'http://x/1.m3u8'},
        {'id': 'vtv3', 'name': 'VTV3', 'primary': 'http://x/3.m3u8'},
      ],
      'youtubeCategories': [
        {
          'id': 'nhac',
          'name': 'Ca nhạc',
          'icon': '🎵',
          'channels': [
            {'name': 'VTV Music', 'channelId': 'UCxxx'}
          ],
        },
      ],
      'movies': [],
    });

    expect(config.findChannelByName('bật vtv3')?.id, 'vtv3');
    expect(config.findChannelByName('xem VTV1')?.id, 'vtv1');
    expect(config.findChannelByName('mở nhạc trữ tình'), isNull);
    expect(config.findCategoryByName('mở nhạc trữ tình')?.id, 'nhac');
    expect(config.findCategoryByName('nhac')?.name, 'Ca nhạc');
    expect(config.findChannelByName('kênh không có'), isNull);
  });
}
