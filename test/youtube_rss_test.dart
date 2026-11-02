import 'package:flutter_test/flutter_test.dart';

import 'package:oumijia_tv/services/youtube_service.dart';

/// RSS YouTube: chỉ lấy videoId/title/published, giải mã entity, tôn trọng limit.
void main() {
  const xml = '''
<?xml version="1.0" encoding="UTF-8"?>
<feed xmlns:yt="http://www.youtube.com/xml/schemas/2015" xmlns:media="http://search.yahoo.com/mrss/">
  <title>Kênh thử</title>
  <entry>
    <id>yt:video:abc123def45</id>
    <yt:videoId>abc123def45</yt:videoId>
    <title>Fallback title</title>
    <published>2026-11-01T10:00:00+00:00</published>
    <media:group>
      <media:title>Tin &amp; sự kiện &lt;hôm nay&gt;</media:title>
    </media:group>
  </entry>
  <entry>
    <yt:videoId>xyz987uvw65</yt:videoId>
    <published>2026-10-30T08:30:00+00:00</published>
    <media:group>
      <media:title>Video thứ hai</media:title>
    </media:group>
  </entry>
  <entry>
    <yt:videoId>ignored00000</yt:videoId>
    <media:group><media:title>Bị cắt bởi limit</media:title></media:group>
  </entry>
</feed>
''';

  test('parse RSS đúng video id, title, ngày', () {
    final videos = YouTubeService.parseRss(xml, limit: 2);
    expect(videos.length, 2);
    expect(videos[0].id, 'abc123def45');
    expect(videos[0].title, 'Tin & sự kiện <hôm nay>');
    expect(videos[0].published, DateTime.parse('2026-11-01T10:00:00+00:00'));
    expect(videos[1].id, 'xyz987uvw65');
    expect(videos[1].title, 'Video thứ hai');
  });

  test('RSS hỏng/rỗng trả danh sách rỗng, không ném lỗi', () {
    expect(YouTubeService.parseRss('<feed></feed>'), isEmpty);
    expect(YouTubeService.parseRss('not xml'), isEmpty);
  });
}
