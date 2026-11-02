# PROJECT AUDIT — OUMIJIA TV

Ngày audit: 2026-11-02 · trước khi tái thiết kế v2.0

## 1. Bối cảnh

- Framework: **Flutter 3.47.8** (Dart 3.x) — Android + iOS. Không đổi framework.
- Repo: github.com/wuwenhou/OUMIJIA-TV (public), branch chính `main`.
- Release hiện tại: v1.0.0 (Android APK 53MB) + v1.0.0-ios (IPA unsigned).
- **Lưu ý**: có 3 commit sau v1.0.0 do chủ dự án thực hiện (không phải build bot):
  - `282a9d4` Remove elderly UI: normal sizes, no auto-play, no font setting
  - `76cd190` Rename build artifacts (build.gradle.kts + ios workflow)
  - `da81528` Fix broken channels: dethich.pw + UA headers + cleartext
  → **Phải bảo vệ toàn bộ thay đổi này.**

## 2. Bảng đánh giá chức năng

| # | Chức năng | Trạng thái | Ghi chú |
|---|---|---|---|
| 1 | phát TV trực tuyến (10 kênh VTV/ANTV, UA headers, fallback URL) | 🟢 Hoàn thành | player + D-pad + retry fallback |
| 2 | Player (landscape/immersive, auto-hide controls, favorite, voice) | 🟢 Hoàn thành | UI cần làm đẹp |
| 3 | Điều khiển remote/D-pad | 🟢 Hoàn thành | giữ nguyên |
| 4 | Giọng nói tiếng Việt (speech_to_text, khớp bỏ dấu) | 🟢 Hoàn thành | có test |
| 5 | In-app updater (GitHub Releases + tải APK + OpenFilex cài đặt) | 🟢 Hoàn thành | update_service + update_dialog; cần restyle |
| 6 | Config JSON từ xa (GitHub raw → cache → bundled) | 🟢 Hoàn thành | v2 có headers |
| 7 | Tab Phim | 🟡 Trống rỗng | movies trong config = [] |
| 8 | Tab YouTube | 🟡 Trống rỗng | youtubeCategories = [] (chủ dự án đã dọn nội dung) |
| 9 | Kênh yêu thích | 🟡 Cần cải thiện | chỉ là toggle trong player, chưa có màn riêng |
| 10 | Giao diện | 🔴 Cần tái thiết kế | flat, ít phân cấp; prompt yêu cầu Premium Dark modern |
| 11 | Cài đặt giao diện (theme mode, màu chủ đạo) | 🔴 Chưa có | cần Light/Dark/System + palette |
| 12 | Độ sáng màn hình riêng | 🔴 Chưa có | cần MethodChannel Kotlin |
| 13 | Danh mục kênh VN (nhóm/lọc/tìm kiếm) | 🔴 Chưa có | cần thêm kênh địa phương + phân nhóm |
| 14 | Channel Health Check | 🔴 Chưa có | cần script kiểm tra stream thực tế |
| 15 | Icon app | 🔴 Mặc định Flutter | cần thiết kế mới + adaptive |
| 16 | CI Android (analyze/test/build APK) | 🔴 Chưa có | mới chỉ có iOS workflow |
| 17 | Branch process (develop/feature) | 🔴 Chưa có | chỉ main |
| 18 | LICENSE/CONTRIBUTING/CHANGELOG | 🔴 Chưa có | — |

## 3. Mã nguồn hiện tại (cần giữ/tận dụng)

```
lib/
├── main.dart                 # bootstrap: Prefs → Config → Home
├── models.dart               # Channel/YouTubeCategory/MovieItem/AppConfig (+headers, matchVoice)
├── ui.dart                   # token màu cứng (sẽ thay bằng design system)
├── screens/                  # home, live, movies, player, settings, youtube
├── services/                 # config, prefs, voice, youtube, update
└── widgets/update_dialog.dart
```

Dữ liệu kênh: `config/channels.json` v2 (10 kênh VTV + ANTV, dethich.pw primary, tvon.vn fallback, UA Chrome/155).

## 4. Quyết định của người auditor

1. **Giữ nguyên**: models, config_service, voice/youtube/update services, tất cả logic player/D-pad.
2. **Tái cấu trúc giao diện hoàn toàn**: design system mới (theme tokens động, light/dark/system, accent palette), 5 màn: Home, Kênh, Phim, YouTube, Cài đặt + màn Yêu thích + khi xem gần đây.
3. **Bổ sung**: MethodChannel độ sáng (Kotlin window-level, không cần quyền hệ thống), channel health check script (fetch playlist + 1 segment thật, có rate-limit), icon mới (generate + adaptive), CI Android, CHANGELOG/CONTRIBUTING/README.
4. **Rủi ro**: `dethich.pw` là nguồn không chính thức — cần health-check thật trước khi công bố trạng thái kênh; kênh mới chỉ thêm sau khi test.

## 5. Phân tích skill thiết kế (design-mobile-apps / Sleek)

- Sleek cần API key + credit trả phí → **không dùng tool tự động**; áp dụng nguyên tắc
  (style direction chuẩn: mood — premium, cinematic; color — dark stage + single accent;
  typography — high-contrast hierarchy; layout — hero + rows; component — soft radii,
  hairline borders thay shadow nặng) trực tiếp vào design system Flutter.
- Mỗi màn hình chia sẻ chung design tokens (không mỗi màn một phong cách).
