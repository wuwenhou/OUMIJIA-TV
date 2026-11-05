# OUMIJIA TV

Ứng dụng xem **truyền hình Việt Nam, phim và YouTube không quảng cáo** — giao diện
streaming hiện đại, tối giản, không quảng cáo. Xây dựng bằng Flutter cho Android
và iOS, tối ưu thao tác đơn giản cho cả gia đình.

## Tính năng

- 📺 **Truyền hình trực tuyến**: kênh VTV, ANTV, HTV, SCTV, các đài địa phương —
  có phân nhóm, tìm kiếm, lọc, danh sách/lưới.
- ⭐ **Yêu thích**: lưu kênh yêu thích tại thiết bị, mở lại từ nút trái tim
  trên thanh công cụ tab Kênh.
- 🎨 **Cài đặt giao diện**: Light / Dark / System, 5 bảng màu chủ đạo,
  cỡ chữ 90–130%, khôi phục mặc định — áp dụng ngay, không cần khởi động lại.
- 🔆 **Độ sáng riêng (Android + iOS)**: Android chỉ đổi cửa sổ ứng dụng
  (`WindowManager.LayoutParams.screenBrightness`), không cần `WRITE_SETTINGS`.
  iOS dùng `UIScreen.main.brightness`, tự khôi phục khi app rời foreground.
- 🎬 **Phim thuyết minh/lồng tiếng**: đọc danh sách video mới nhất từ kênh
  YouTube chính thức (iQIYI Phim Thuyết Minh, Phim Lồng Tiếng Hay) qua
  Innertube/trang kênh — video mới tự xuất hiện, phát không quảng cáo bằng
  trình phát sẵn có. Kèm danh mục `movies` thủ công trong cấu hình cho nội
  dung có bản quyền khác.
- ▶️ **YouTube không quảng cáo**: bảng tin video theo chủ đề + tìm kiếm tự do,
  phát trực tiếp bằng luồng của video (không iframe/webview, không quảng cáo).
  Không cần duyệt kênh trước.
- 🕹️ **Remote TV**: D-pad đổi kênh, OK dừng/phát, Back thoát.
- 🌙 **Dừng phát khi rời app**: TV, phim và YouTube tự dừng khi app vào nền
  hoặc tắt màn hình; quay lại mới tự phát tiếp (trừ khi người dùng đã bấm dừng).
- 🔄 **Cập nhật trong app**: kiểm tra GitHub Releases, tải APK, mở trình cài đặt
  (người dùng vẫn xác nhận cài như Android yêu cầu).
- 📡 **Trạng thái kênh**: WORKING / DEGRADED / OFFLINE / INVALID / UNVERIFIED,
  kênh không có nguồn hợp lệ sẽ bị đánh dấu và không mở.

## Nền tảng

Android + iOS (Flutter 3.47.8). Không có bản web.

## Cấu hình nội dung

Toàn bộ kênh và phim nằm trong `config/channels.json`. Tab YouTube lấy bảng tin
theo từ khóa trực tiếp từ YouTube, không phụ thuộc danh sách kênh đã duyệt.
App nạp theo thứ tự: **GitHub (main) → bản lưu trên máy → bản đóng gói trong APK**.
Sửa file trên GitHub là cập nhật nội dung cho mọi máy — không cần phát hành APK mới.

Nguồn phim động (kênh YouTube chính thức, cập nhật liên tục):

```json
{
  "movieSources": [
    {
      "id": "iqiyi-thuyet-minh",
      "name": "iQIYI Phim Thuyết Minh",
      "channelId": "UC_mLtI_EeKBXkNew8QsFkYg",
      "note": "Phim châu Á thuyết minh tiếng Việt."
    }
  ]
}
```

App đọc danh sách video công khai của kênh qua Innertube (`youtubei/v1/browse`,
dự phòng: trang `/channel/<id>/videos`) và phát qua trình phát YouTube sẵn có;
không tải lại hay phân phối nội dung. Chỉ thêm kênh chính thức có quyền phát
nội dung đó.

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
gh release create v2.1.0 "OUMIJIA-TV v2.1.0.apk" "OUMIJIA-TV v2.1.0.ipa" \
  --title "OUMIJIA TV v2.1.0" --notes-file CHANGELOG.md
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
├── config/channels.json        # Danh mục kênh/phim (phát hành qua GitHub)
├── lib/
│   ├── theme/                  # Design system + controller giao diện
│   ├── screens/                # Home, Kênh, Phim, YouTube, Cài đặt, Player, Yêu thích
│   ├── services/               # config, prefs, brightness, youtube, update
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
- Độ sáng iOS là độ sáng màn hình hệ thống trong lúc app đang mở; app tự khôi
  phục mức cũ khi rời foreground hoặc kết thúc. Nếu app bị buộc dừng đột ngột,
  iOS có thể giữ mức sáng đã đặt cho đến khi người dùng chỉnh lại.
- Bảng tin YouTube đọc dữ liệu công khai từ trang tìm kiếm YouTube; nếu YouTube
  đổi cấu trúc trang, tab YouTube có thể tạm trống cho đến khi cập nhật parser.
- Chưa có bản web; YouTube không hỗ trợ đăng nhập/tài khoản cá nhân.

## Giấy phép

Xem [LICENSE](LICENSE): phần mềm dùng cho mục đích cá nhân/gia đình, không phải
mã nguồn mở. Nội dung, logo và luồng phát thuộc bản quyền của các đài/nhà cung
cấp tương ứng.
