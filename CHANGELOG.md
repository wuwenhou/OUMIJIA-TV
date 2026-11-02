# Changelog

Mọi thay đổi đáng chú ý của OUMIJIA TV được ghi tại đây.
Định dạng dựa trên [Keep a Changelog](https://keepachangelog.com/vi/1.1.0/),
phiên bản theo [Semantic Versioning](https://semver.org/lang/vi/).

## [2.0.0] — 2026-11-02

Bản tái thiết kế giao diện và hoàn thiện hệ thống kênh.

### Thêm mới
- **Design System** thống nhất: token màu Light/Dark, 5 bảng màu chủ đạo
  (Vàng OUMIJIA, Biển, Tím, Xanh lá, Hồng), thang khoảng cách/bo góc dùng chung.
- **Cài đặt giao diện**: Light / Dark / System áp dụng ngay; đổi màu chủ đạo;
  cỡ chữ 90–130%; nút Khôi phục mặc định; lưu tại thiết bị.
- **Độ sáng riêng của ứng dụng (Android)**: MethodChannel
  `oumijia_tv/brightness` → `WindowManager.LayoutParams.screenBrightness`.
  Không đổi độ sáng hệ thống, không cần quyền WRITE_SETTINGS; tắt là trả về mặc định.
- **Tab Kênh mới**: tìm kiếm không dấu, lọc theo nhóm, chuyển List/Grid
  (lưu lựa chọn), kéo xuống để nạp lại cấu hình từ GitHub.
- **Màn Kênh yêu thích** riêng + hàng "Vừa xem" (10 kênh gần nhất).
- **Trạng thái kênh**: WORKING / DEGRADED / OFFLINE / INVALID / UNVERIFIED,
  hiển thị trên card và chặn mở kênh không có nguồn hợp lệ.
- **Channel Health Check** (`tools/channel_health.ps1`): kiểm tra playlist →
  variant → segment đầu tiên, xác thực container TS/fMP4; rate-limit, cache 6h;
  xuất báo cáo JSON + HTML trong `tools/reports/`.
- **CI Android** (`.github/workflows/android.yml`): analyze, test, build APK,
  tự tạo GitHub Release khi push tag `v*`.
- **Icon ứng dụng mới** (Android adaptive + iOS), tông vàng trên nền tối.

### Thay đổi
- **Toàn bộ giao diện** chuyển sang phong cách streaming hiện đại: nền tối
  "premium stage", phân cấp rõ, thẻ kênh có logo + trạng thái, hero
  "Tiếp tục xem", điều hướng 5 tab, animation nhẹ.
- **Trình phát**: overlay mới (logo, tên kênh, chip LIVE), nút điều khiển
  tối giản, thêm nút **Thử lại** khi mất kết nối; giữ nguyên D-pad, fallback URL,
  giọng nói, yêu thích.
- **Màn Cài đặt**: chia mục Giao diện / Độ sáng / Trình phát & cập nhật /
  Điều khiển TV / Về ứng dụng.
- **Cập nhật trong app**: kiểm tra thầm lặng khi mở app (không chặn khởi động),
  hộp thoại mới hiển thị phiên bản + dung lượng + ghi chú; giữ nguyên cơ chế
  tải APK và mở trình cài đặt của Android.
- **Phim / YouTube**: giao diện mới, trạng thái rỗng rõ ràng, nút thử lại khi lỗi.
- README, CHANGELOG, CONTRIBUTING, LICENSE (quyền sử dụng nội bộ) được chuẩn hoá.

### Sửa lỗi
- Hàng "Tiếp tục xem" không còn hiển thị kênh không tồn tại trong danh mục.
- Danh sách kênh tự làm mới sau khi đóng trình phát (yêu thích / vừa xem / badge).
- Kênh không có nguồn phát hợp lệ được báo rõ thay vì mở màn hình lỗi.

### Ghi chú
- Danh mục Phim và YouTube vẫn để trống nếu cấu hình không có nội dung hợp lệ —
  không tạo dữ liệu giả. Chủ ứng dụng bổ sung qua `config/channels.json`.
- Kết quả kiểm thử thiết bị thật và kết quả health check từng đợt được ghi trong
  `tools/reports/` và báo cáo phát hành.

## [1.0.1] — 2026-11-01
- Sửa nguồn phát hỏng (dethich.pw + User-Agent + cleartext), đổi tên file build.
- Bỏ giao diện phóng đại dành cho người cao tuổi; cỡ chữ bình thường.

## [1.0.0] — 2026-10-31
- Bản đầu tiên: VTV1–VTV10, ANTV, trình phát D-pad, giọng nói tiếng Việt,
  cập nhật trong app, APK + IPA.
