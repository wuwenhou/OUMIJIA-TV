# Đóng góp cho OUMIJIA TV

Cảm ơn bạn quan tâm. Dự án ưu tiên thay đổi **nhỏ, có kiểm soát, dễ rollback**.

## Quy trình nhánh

| Nhánh | Mục đích |
|---|---|
| `main` | Bản ổn định, đã qua kiểm thử, dùng để phát hành |
| `develop` | Tích hợp tính năng đang phát triển |
| `feature/<ten>` | Tính năng mới, tách từ `develop` |
| `fix/<ten>` | Sửa lỗi thường |
| `release/<x.y.z>` | Chuẩn bị phát hành |
| `hotfix/<ten>` | Sửa khẩn cấp từ `main` |

- Không push trực tiếp lên `main`.
- Thay đổi lớn mở Pull Request vào `develop`, kèm mô tả, ảnh trước/sau (nếu là UI),
  kết quả `flutter analyze` / `flutter test` / build APK.
- Chỉ merge `develop` → `main` khi CI xanh và đã kiểm thử.

## Commit — Conventional Commits

```
feat: thêm bộ lọc nhóm kênh
fix: giữ nguyên độ sáng khi xoay màn hình
refactor: tách widget kênh dùng chung
style: cập nhật khoảng cách thẻ kênh
docs: bổ sung hướng dẫn health check
test: thêm test tìm kênh không dấu
build: thêm workflow Android CI
```

Mỗi commit nên giải quyết một việc; không gộp thay đổi không liên quan.

## Quy tắc dữ liệu kênh

- **Không bịa URL phát sóng**, không thêm kênh "đang hoạt động" khi chưa kiểm tra.
- Chỉ dùng nguồn công khai, được phép sử dụng.
- Trước khi thêm kênh mới, chạy:

```powershell
powershell -ExecutionPolicy Bypass -File tools/channel_health.ps1 -ConfigPath config/channels.json
```

- Kênh không có nguồn hợp lệ: vẫn giữ thông tin nhưng đặt `health` = `OFFLINE`
  hoặc `UNVERIFIED` và `primary` rỗng — app sẽ hiển thị "chưa khả dụng".
- Không kiểm tra dồn dập: script đã có rate-limit và cache; giữ nguyên hoặc tăng.

## Quy tắc bảo mật

- Không commit keystore, mật khẩu, token, `key.properties`, file cấu hình cá nhân.
- Không nhúng API key vào mã nguồn.
- Không tự ý đổi giấy phép của các thành phần bên thứ ba.

## Kiểm tra trước khi gửi PR

```bash
flutter pub get
flutter analyze        # phải 0 lỗi
flutter test
flutter build apk --release
```

Ghi rõ trong PR:
- Mục tiêu thay đổi.
- File/module bị ảnh hưởng.
- Kết quả kiểm thử và phần **chưa** kiểm chứng được (ví dụ: chưa có thiết bị thật).
- Lỗi còn tồn tại (nếu có).

## Phong cách mã

- Dart chuẩn `flutter_lints`; ưu tiên widget nhỏ, tái sử dụng design token
  trong `lib/theme/design_system.dart`.
- Chuỗi hiển thị bằng tiếng Việt, có dấu.
- Không thêm animation nặng hoặc làm chậm khởi động.
