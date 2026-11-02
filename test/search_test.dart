import 'package:flutter_test/flutter_test.dart';

import 'package:oumijia_tv/models.dart';

/// Test tìm kiếm kênh không dấu và trạng thái khả dụng.
/// Không cần khởi tạo SharedPreferences hay Flutter binding.
void main() {
  final config = AppConfig.fromJson({
    'channels': [
      {
        'id': 'vtv3',
        'name': 'VTV3',
        'group': 'Giải trí',
        'logo': '',
        'primary': 'http://x/3.m3u8',
        'health': 'WORKING',
      },
      {
        'id': 'danang1',
        'name': 'Đà Nẵng TV 1',
        'group': 'Địa phương',
        'logo': '',
        'primary': 'http://x/dn.m3u8',
        'health': 'OFFLINE',
      },
      {
        'id': 'antv',
        'name': 'ANTV',
        'group': 'Tin tức',
        'logo': '',
        'primary': '',
        'health': 'UNVERIFIED',
      },
    ],
    'youtubeCategories': [],
    'movies': [],
  });

  test('tìm kênh bỏ dấu, không phân biệt hoa thường', () {
    expect(config.searchChannels('da nang').map((c) => c.id), ['danang1']);
    expect(config.searchChannels('ĐÀ NẴNG').single.id, 'danang1');
    expect(config.searchChannels('giai tri').map((c) => c.id), ['vtv3']);
    expect(config.searchChannels('vtv').map((c) => c.id), ['vtv3']);
    expect(config.searchChannels('tin tuc').map((c) => c.id), ['antv']);
    expect(config.searchChannels('   ').length, 3);
    expect(config.searchChannels('khong co'), isEmpty);
  });

  test('kênh OFFLINE hoặc thiếu URL bị đánh dấu không khả dụng', () {
    final offline = config.channels.firstWhere((c) => c.id == 'danang1');
    expect(offline.health, 'OFFLINE');
    expect(offline.unavailable, isTrue);

    final empty = config.channels.firstWhere((c) => c.id == 'antv');
    expect(empty.unavailable, isTrue);

    final working = config.channels.firstWhere((c) => c.id == 'vtv3');
    expect(working.health, 'WORKING');
    expect(working.unavailable, isFalse);
  });

  test('mặc định trạng thái là UNVERIFIED khi cấu hình thiếu', () {
    final c = Channel.fromJson({
      'id': 'x',
      'name': 'X',
      'primary': 'http://x/x.m3u8',
    });
    expect(c.health, 'UNVERIFIED');
    expect(c.lastVerified, '');
    expect(c.unavailable, isFalse);
  });
}
