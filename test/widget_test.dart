import 'package:flutter_test/flutter_test.dart';

import 'package:oumijia_tv/models.dart';

void main() {
  test('AppConfig đọc kênh, phim và tìm kiếm không dấu', () {
    final config = AppConfig.fromJson({
      'channels': [
        {'id': 'vtv1', 'name': 'VTV1', 'primary': 'http://x/1.m3u8'},
        {'id': 'vtv3', 'name': 'VTV3', 'primary': 'http://x/3.m3u8'},
      ],
      'movies': [
        {
          'id': 'phim-1',
          'title': 'Phim thử',
          'poster': '',
          'url': 'http://x/phim.m3u8',
        },
      ],
    });

    expect(config.channels.map((c) => c.id), ['vtv1', 'vtv3']);
    expect(config.movies.single.title, 'Phim thử');
    expect(config.searchChannels('vtv3').single.id, 'vtv3');
    expect(config.searchChannels('khong co'), isEmpty);
  });
}
