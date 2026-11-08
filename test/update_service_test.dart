import 'package:flutter_test/flutter_test.dart';

import 'package:oumijia_tv/services/update_service.dart';

void main() {
  test('diễn giải lỗi tải HTTP 504 thành thông báo tiếng Việt dễ hiểu', () {
    expect(
      UpdateService.friendlyDownloadError(Exception('HTTP 504')),
      'Máy chủ GitHub đang quá tải. Vui lòng thử lại sau vài phút.',
    );
  });
}
