# OUMIJIA TV

Ứng dụng xem **truyền hình Việt Nam, phim và YouTube tuyển chọn** — giao diện
streaming hiện đại, tối giản, không quảng cáo. Xây dựng bằng Flutter cho Android
và iOS, tối ưu thao tác đơn giản cho cả gia đình.

## Tính năng

- 📺 **Truyền hình trực tuyến**: kênh VTV, ANTV, HTV, SCTV, các đài địa phương —
  có phân nhóm, tìm kiếm, lọc, danh sách/lưới.
- ⭐ **Yêu thích & vừa xem**: lưu kênh yêu thích, hàng "Tiếp tục xem" và
  "Vừa xem" trên trang chủ; lưu tại thiết bị.
- 🎨 **Cài đặt giao diện**: Light / Dark / System, 5 bảng màu chủ đạo,
  cỡ chữ 90–130%, khôi phục mặc định — áp dụng ngay, không cần khởi động lại.
- 🔆 **Độ sáng riêng (Android)**: điều chỉnh độ sáng chỉ cho cửa sổ ứng dụng
  (`WindowManager.LayoutParams.screenBrightness`), không đổi độ sáng hệ thống,
  không cần quyền `WRITE_SETTINGS`.
- 🎬 **Phim**: danh mục cấu hình từ xa, poster, trình phát toàn màn hình.
- ▶️ **YouTube tuyển chọn**: chỉ danh mục đã duyệt, phát không quảng cáo,
  playlist chạy liên tục.
- 🎙️ **Giọng nói tiếng Việt & remote TV**: nói "Bật VTV3"; D-pad đổi kênh,
  OK dừng/phát, Back thoát.
- 🔄 **Cập nhật trong app**: kiểm tra GitHub Releases, tải APK, mở trình cài đặt
  (người dùng vẫn xác nhận cài như Android yêu cầu).
- 📡 **Trạng thái kênh**: WORKING / DEGRADED / OFFLINE / INVALID / UNVERIFIED,
  kênh không có nguồn hợp lệ sẽ bị đánh dấu và không mở.

## Nền tảng

Android + iOS (Flutter 3.47.8). Không có bản web.

## Cấu hình nội dung

Toàn bộ kênh, phim, danh mục YouTube nằm trong `config/channels.json`.
App nạp theo thứ tự: **GitHub (main) → bản lưu trên máy → bản đóng gói trong APK**.
Sửa file trên GitHub là cập nhật nội dung cho mọi máy — không cần phát hành APK mới.

Mỗi kênh hỗ trợ:

```json
{
  "id": "vtv1",
  "name": "VTV1",
  "group": "Quốc gia",
  "logo": "https://...",
  "primary": "https://.../index.m3u8",
  "fallback": ["https://.../index.m3u8"],
  "headers": { "User-Agent": "Mozilla/5.0 ..." },
  "health": "WORKING",
  "lastVerified": "2026-11-02"
}
```

Nguyên tắc: **không tạo URL giả, không đánh dấu kênh hoạt động khi chưa kiểm tra**.
Kênh chưa có nguồn hợp lệ vẫn được giữ trong danh mục nhưng đặt `health` =
`OFFLINE`/`UNVERIFIED` và `primary` rỗng.

## Kiểm tra sức khoẻ kênh

Công cụ: `tools/channel_health.ps1` (Windows PowerShell 5.1+).

```powershell
# Kiểm tra toàn bộ kênh trong cấu hình
powershell -ExecutionPolicy Bypass -File tools/channel_health.ps1

# Kiểm tra danh sách ứng viên từ iptv-org (không ảnh hưởng config)
powershell -ExecutionPolicy Bypass -File tools/channel_health.ps1 `
  -M3uPath https://iptv-org.github.io/iptv/countries/vn.m3u `
  -ReportName candidates

# Ghi kết quả health/lastVerified trở lại config
powershell -ExecutionPolicy Bypass -File tools/channel_health.ps1 -UpdateConfig
```

Cách hoạt động: tải playlist → theo variant đầu tiên → tải segment đầu tiên
(EXT-X-MAP với fMP4 hoặc segment TS) → kiểm tra chữ ký container
(TS `0x47`, fMP4 `ftyp/styp/moof`). Có timeout, rate-limit 800ms và cache 6 giờ.
Kết quả: `tools/reports/channel-health.json` + `.html`.

> Đây là kiểm tra hạ tầng/container — **không thay thế** kiểm thử giải mã
> hình/tiếng trên thiết bị thật. Phần chưa kiểm chứng luôn được ghi rõ trong
> báo cáo phát hành.

## Build

Yêu cầu: Flutter 3.47.8+, Java 17, Android SDK; Xcode 26 cho iOS.

```bash
flutter pub get
flutter analyze         # mục tiêu: 0 lỗi
flutter test
flutter build apk --release
# iOS (không ký):
flutter build ios --release --no-codesign
```

APK release lấy từ `build/app/outputs/flutter-apk/app-release.apk`.
Ký phát hành: tạo `android/key.properties` (đã gitignore) trỏ tới keystore riêng;
CI dùng GitHub Secrets `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`,
`KEY_ALIAS` để tạo file này trước khi build. Không commit keystore/key.properties.

> Đổi khóa ký sẽ khiến Android từ chối cài đè — cần gỡ app một lần rồi cài lại.
> Từ v2.0.2, khóa phát hành đã cố định nên các bản sau cập nhật bình thường.

## CI/CD

- `.github/workflows/android.yml` — analyze + test + build APK trên PR/push;
  push tag `v*` tự tạo GitHub Release kèm APK.
- `.github/workflows/ios-build.yml` — build IPA unsigned trên `macos-26`
  (cần Xcode mới nhất cho `video_player_avfoundation`).

Phát hành thủ công:

```bash
gh release create v2.0.0 "OUMIJIA-TV v2.0.0.apk" "OUMIJIA-TV v2.0.0.ipa" \
  --title "OUMIJIA TV v2.0.0" --notes-file CHANGELOG.md
```

## Cài đặt

### Android
Tải APK ở mục [Releases](https://github.com/wuwenhou/OUMIJIA-TV/releases) →
mở file → cho phép "cài từ nguồn không xác định" → cài. Hỗ trợ Android TV box
qua remote (D-pad).

### iOS
IPA unsigned build trên GitHub Actions (Actions → run → Artifacts →
`oumijia-tv-ios`) hoặc đính kèm trong Release. Cài bằng **Sideloadly** hoặc
**AltStore** với Apple ID cá nhân; chứng chỉ miễn phí hết hạn sau 7 ngày.

## Cấu trúc

```
oumijia_tv/
├── config/channels.json        # Danh mục kênh/phim/YouTube (phát hành qua GitHub)
├── lib/
│   ├── theme/                  # Design system + controller giao diện
│   ├── screens/                # Home, Kênh, Phim, YouTube, Cài đặt, Player, Yêu thích
│   ├── services/               # config, prefs, brightness, voice, youtube, update
│   └── widgets/                # ChannelCard, dialog cập nhật...
├── tools/
│   ├── channel_health.ps1      # Kiểm tra nguồn phát + báo cáo
│   ├── make_icon.ps1           # Sinh icon launcher
│   └── reports/                # Báo cáo health (JSON + HTML)
├── android/ · ios/
├── CHANGELOG.md · CONTRIBUTING.md
└── PROJECT_AUDIT.md            # Đánh giá trước tái thiết kế
```

## Giới hạn & miễn trừ

- Nguồn phát là các luồng công khai của đài truyền hình/nhà cung cấp; có thể
  thay đổi hoặc chặn theo vùng địa lý. App không lưu trữ hay phân phối lại video.
- Một số kênh chỉ hoạt động trong mạng Việt Nam; trạng thái kiểm tra phụ thuộc
  mạng tại thời điểm chạy.
- Tính năng độ sáng riêng chỉ có trên Android; iOS dùng độ sáng hệ thống.

## Giấy phép

Xem [LICENSE](LICENSE): phần mềm dùng cho mục đích cá nhân/gia đình, không phải
mã nguồn mở. Nội dung, logo và luồng phát thuộc bản quyền của các đài/nhà cung
cấp tương ứng.
