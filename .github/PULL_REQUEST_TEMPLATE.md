# Mô tả thay đổi

<!-- Tóm tắt ngắn: thay đổi gì, vì sao. -->

## Loại thay đổi

- [ ] Tính năng mới (`feat`)
- [ ] Sửa lỗi (`fix`)
- [ ] Tái cấu trúc (`refactor`)
- [ ] Giao diện (`style`)
- [ ] Tài liệu (`docs`)
- [ ] Kiểm thử (`test`)
- [ ] Build/CI (`build`)

## File / module ảnh hưởng

<!-- Ví dụ: lib/screens/channels_screen.dart, config/channels.json -->

## Kiểm thử đã chạy

- [ ] `flutter analyze` — 0 lỗi
- [ ] `flutter test` — pass
- [ ] `flutter build apk --release`
- [ ] Kiểm tra trên thiết bị thật (ghi rõ model Android/iOS)
- [ ] `tools/channel_health.ps1` (nếu thay đổi kênh)

Kết quả / số liệu:

<!-- Dán tóm tắt kết quả, ví dụ: WORKING 43 / DEGRADED 12 / UNVERIFIED 25 -->

## Ảnh giao diện

<!-- Trước / sau nếu thay đổi UI. -->

## Phần chưa kiểm chứng

<!-- Trung thực: ví dụ chưa có thiết bị Android thật, chưa test iOS. -->

## Checklist

- [ ] Không commit secrets/keystore/token
- [ ] Không thêm URL kênh giả hoặc chưa xác minh mà không đánh dấu
- [ ] Cập nhật CHANGELOG/README nếu cần
- [ ] Giữ tương thích cấu hình `config/channels.json`
