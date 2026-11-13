# Changelog

Mọi thay đổi đáng chú ý của OUMIJIA TV được ghi tại đây.
Định dạng dựa trên [Keep a Changelog](https://keepachangelog.com/vi/1.1.0/),
phiên bản theo [Semantic Versioning](https://semver.org/lang/vi/).

## [2.1.9] — 2026-11-13

### Thay đổi
- **Vuốt lên/xuống để đổi kênh** ngay trong trình phát: vuốt lên sang kênh sau, vuốt xuống về kênh trước; đổi vòng khi ở đầu/cuối danh sách.
- Ngưỡng vuốt 64 px hoặc 350 px/giây để tránh đổi kênh khi tay run nhẹ; mỗi cử chỉ chỉ đổi một kênh, có rung nhẹ xác nhận.
- Thanh điều khiển tự hiện khi đổi kênh và tự ẩn lại sau 5 giây; danh sách chỉ có một kênh thì không khởi động lại luồng phát.
- **Nút X thoát lớn hơn**: 56×56 dp, icon 28, giữ trong vùng an toàn khi xoay dọc/ngang.
- Cập nhật dòng gợi ý dưới đáy thành “Vuốt lên/xuống đổi kênh · Chạm để hiện/ẩn”.

### Kiểm thử
- `dart analyze`: 0 lỗi.
- `flutter test`: 29/29 pass, gồm vuốt đổi kênh, vuốt quá ngắn không đổi, vòng danh sách, nút thoát 56×56 và layout ngang 844×390 ở mức chữ 130%.

## [2.1.8] — 2026-11-09

### Thay đổi
- **Quay về giao diện kênh cũ**: danh sách dọc quen thuộc, thanh điều hướng dưới ở mọi hướng màn hình; bỏ NavigationRail/lưới kênh tự động khi xoay ngang.
- **Bỏ thanh tìm kiếm và hàng chip lọc nhóm** khỏi tab Kênh, đồng thời bỏ nút chuyển list/lưới. Tab Kênh chỉ còn tiêu đề, nút yêu thích, số kênh và danh sách dọc.
- Giữ nguyên các cải tiến hiện có: kênh yêu thích lên đầu, cỡ chữ cơ bản lớn hơn và đủ to cho người già ở mức 130%.

### Kiểm thử
- `dart analyze`: 0 lỗi.
- `flutter test`: 25/25 pass, gồm test giao diện cũ không còn TextField/ChoiceChip/SegmentedButton/lưới và thanh dưới vẫn xuất hiện khi xoay ngang.

## [2.1.7] — 2026-11-09

### Thay đổi
- **Chế độ ngang gọn**: khi xoay ngang, thanh điều hướng dưới chuyển thành NavigationRail bên trái; tab Kênh rút tiêu đề còn “Kênh”, giảm padding/chiều cao chip lọc, ẩn dòng số kênh và tự chuyển sang lưới 3–4 cột để thấy nhiều kênh hơn, chọn nhanh hơn.
- **Tăng cỡ chữ cơ bản**: ở mức 100%, chữ tên kênh, tiêu đề, nội dung, trạng thái và nút bấm lớn hơn khoảng 10–15%. Ở mức 130%, chữ đủ lớn cho người già đọc.

### Kiểm thử
- `dart analyze`: 0 lỗi.
- `flutter test`: 23/23 pass, gồm test NavigationRail ở ngang, lưới kênh ở ngang và cỡ chữ 100%/130%.

## [2.1.6] — 2026-11-08

### Thay đổi
- **Đổi icon/launcher sang phiên bản Tết**: nền đỏ gradient, chữ “TV” trắng rất lớn ở giữa, điểm nhấn vàng gồm đèn lồng, hoa mai và pháo hoa. Góc của icon được bo nhẹ. Bộ icon mới được đồng bộ cho Android adaptive icon và iOS; nền adaptive icon cũng chuyển sang đỏ.

### Kiểm thử
- Đã tạo lại bộ icon bằng `flutter_launcher_icons` cho Android và iOS.

## [2.1.5] — 2026-11-08

### Sửa lỗi
- **Không cập nhật được, báo HTTP 504**: GitHub đôi khi trả 502/503/504 cho
  link tải trực tiếp `browser_download_url` trong khi endpoint API của asset
  với `Accept: application/octet-stream` vẫn tải được. Bộ cập nhật nay dùng
  endpoint API trước, fallback sang link trực tiếp, tự thử lại tối đa 3 lần
  khi server quá tải và hiển thị thông báo tiếng Việt dễ hiểu thay vì xấu xí
  dump `Exception: HTTP 504`.

### Kiểm thử
- `dart analyze`: 0 lỗi.
- `flutter test`: thêm test diễn giải lỗi HTTP 504 thành tiếng Việt.
- Kiểm tra thực tế: link trực tiếp v2.1.3/v2.1.4 trả 504; endpoint API asset
  với tiêu đề `application/octet-stream` tải đủ 59.217.978 byte.

## [2.1.4] — 2026-11-08

### Thay đổi
- **Kênh yêu thích lên đầu danh sách**: kênh có dấu tim được sắp xếp trước các kênh còn lại. Thứ tự gốc trong từng nhóm được giữ nguyên; khi lọc nhóm hoặc tìm kiếm, kênh yêu thích tương ứng vẫn lên đầu. Nút Kênh trước/Sau trong trình phát đi theo cùng thứ tự.
- **Trình phát không còn logo kênh ở góc trên bên trái**: chỉ còn tên kênh, trạng thái LIVE, nút yêu thích và nút đóng; không tải logo trong overlay.
- **Đổi icon/launcher của app**: bộ icon mới dùng gradient xanh dương – tím, biểu tượng TV với Play vàng và chữ “OUMIJIA TV”, đồng bộ cho Android adaptive icon và iOS.

### Kiểm thử
- `dart analyze`: 0 lỗi.
- `flutter test`: 19/19 pass, gồm test kênh yêu thích lên đầu và trình phát không chứa `ChannelLogo`.
- Đã tạo lại icon bằng `flutter_launcher_icons` cho Android và iOS.

### Chưa kiểm chứng trên thiết bị thật
- Chưa có Android/iOS thật trong môi trường build để xác nhận trực tiếp thứ tự yêu thích, giao diện trình phát và icon launcher trên máy.

## [2.1.3] — 2026-11-08

### Sửa lỗi
- **Danh sách kênh ở cỡ chữ lớn bị lệch/chồng chữ**: bỏ logo bên trái tên kênh
  (cả list lẫn grid), tên và trạng thái tự co giãn theo chiều rộng/chiều cao.
  Hàng số kênh không còn dùng `Spacer`, nên text không chạm nhau khi người dùng
  đặt cỡ chữ lớn.
- **Trình phát TV không hiện điều khiển khi chạm vùng đen**: trước đây chỉ chạm
  đúng vùng video sáng mới bật overlay. Nay bất kỳ vùng nào trên màn hình trình
  phát (kể cả dải đen trên/dưới) đều bật/tắt thanh điều khiển. Nút Kênh trước,
  Kênh sau, phát/tạm dừng và đóng vẫn bấm bình thường.
- **Tab Phim hay gặp video sắp công chiếu (Premiere)**: bộ lọc parser bỏ video
  có thời gian tương lai như “25 giờ nữa” khỏi danh sách. Nếu video bị YouTube
  chặn nguồn do premiere/vùng/thiếu quyền, trình phát chỉ hiện thông báo tiếng
  Việt dễ hiểu thay vì xấu xí dump `VideoUnplayableException`.
- Nguồn phim động được mở rộng ngoài iQIYI: thêm kênh chính thức
  `SCTV14 — Kênh Phim Việt (Official)` và `HTVC Phim Thuần Việt`, cả hai đều
  có video mới liên tục và phát trực tiếp không quảng cáo qua trình phát sẵn có.

### Kiểm thử
- `flutter analyze`: 0 lỗi.
- `flutter test`: pass toàn bộ, gồm test mới cho `ChannelCard` không logo ở
  cỡ chữ 130%, parser bỏ premiere, và chạm vùng đen để ẩn thanh điều khiển.
- Kiểm tra mạng thực tế: cả ba kênh iQIYI/SCTV14/HTVC trả 20 video mới nhất;
  ba video mẫu đều có luồng phát muxed (`stream=OK`).

### Chưa kiểm chứng trên thiết bị thật
- Chưa có Android/iOS thật trong môi trường build: chưa xác nhận trực tiếp
  việc chạm vùng đen trên màn hình thật, tải thumbnail và phát phim trên máy.

## [2.1.2] — 2026-11-05

### Sửa lỗi
- **Tab Phim báo "Kênh phim trả HTTP 404"**: YouTube đã ngừng trả feed
  `feeds/videos.xml` cho nhiều kênh (trong đó có cả hai kênh iQIYI), dù kênh
  vẫn đăng video bình thường. Bỏ hẳn phụ thuộc RSS.
- Chuyển sang đọc danh sách video qua **Innertube** (`youtubei/v1/browse`,
  tab Videos) và dự phòng bằng trang `/channel/<id>/videos`; cả hai dùng
  chung parser `lockupViewModel` mới (tiêu đề, thời lượng, lượt xem, ngày đăng).
- Ảnh thu nhỏ dựng trực tiếp từ `i.ytimg.com/vi/<id>/hqdefault.jpg`, không phụ
  thuộc URL có chữ ký hết hạn.

### Kiểm thử
- Chạy thật với hai kênh iQIYI: mỗi kênh trả 20 video mới nhất, có thời lượng,
  lượt xem và ngày đăng (ví dụ `55:46`, `16 giờ trước`).
- `flutter analyze` + `flutter test` pass; thêm test parser `lockupViewModel`
  (bỏ playlist, chống trùng, tôn trọng limit).

### Chưa kiểm chứng trên thiết bị thật
- Chưa có Android/iOS thật trong môi trường build: chưa xác nhận trực tiếp
  việc tải thumbnail và phát video iQIYI trên máy.

## [2.1.1] — 2026-11-04

### Sửa lỗi
- **VTV1 / VTV3 mất tiếng**: nguồn `live.tvon.vn/g2/<id>/video_hd_compat/`
  chỉ chứa track video (init segment `vide`/`avc1`). Chuyển sang `master.m3u8`,
  nơi khai báo audio riêng `audio/playlist.m3u8` (AAC `mp4a`) — ExoPlayer và
  AVPlayer tự ghép hình + tiếng. Áp dụng cho VTV1, VTV3 và VTV10.
- **Bỏ tab Trang chủ**: điều hướng còn 4 tab Kênh · Phim · YouTube · Cài đặt;
  app mở thẳng vào danh sách kênh. Nút "Kênh yêu thích" được đưa lên thanh
  công cụ tab Kênh để không mất chức năng đã có.

### Thêm
- **Nguồn phim thuyết minh/lồng tiếng cập nhật liên tục**: tab Phim đọc RSS
  công khai của hai kênh YouTube chính thức thuộc iQIYI —
  `iQIYI Phim Thuyết Minh` và `Phim Lồng Tiếng Hay`. Mỗi nguồn là một hàng
  ngang video mới nhất; bấm vào phát ngay bằng trình phát YouTube sẵn có
  (không quảng cáo, không iframe). Có cache 10 phút, kéo xuống để làm mới,
  báo lỗi và thử lại riêng từng nguồn.
- Cấu hình `movieSources` trong `config/channels.json`: thêm/bớt kênh phim
  bằng `id`, `name`, `channelId`, `note` — không cần phát hành APK mới.

### Kiểm thử
- `flutter analyze`: 0 lỗi (chỉ còn 2 gợi ý doc-comment trong `tool/`).
- `flutter test`: bổ sung test parser RSS kênh phim và test điều hướng 4 tab
  (không còn "Trang chủ").

### Chưa kiểm chứng trên thiết bị thật
- Chưa có Android/iOS thật trong môi trường build: chưa xác nhận trực tiếp
  âm thanh VTV1/VTV3, luồng phát phim iQIYI và cài đè trong app. Đã kiểm tra
  bằng HTTP: `master.m3u8` trả về audio track AAC; RSS hai kênh trả video mới.

## [2.1.0] — 2026-11-04

### Thay đổi
- **Home 3 khu vực đúng thứ tự**: Truyền hình → Phim → YouTube; bỏ danh sách
  toàn bộ kênh dài trên Home, thêm hàng poster phim và thẻ giới thiệu YouTube.
  Tab chỉ được dựng khi mở lần đầu để tránh gọi mạng lúc khởi động.
- **YouTube kiểu bảng tin**: tìm kiếm tự do + chip chủ đề (Tin tức, Âm nhạc,
  Phim, Hài, Thiếu nhi, Thể thao, Công nghệ, Du lịch), danh sách video có
  thumbnail/thời lượng/kênh/lượt xem. Bỏ cơ chế danh mục kênh được duyệt.
  Dữ liệu đọc từ `ytInitialData` của trang tìm kiếm YouTube, có cache 10 phút
  và gộp request trùng; phát trực tiếp không quảng cáo.
- **Độ sáng iOS**: thêm MethodChannel native dùng `UIScreen.main.brightness`,
  tự khôi phục độ sáng hệ thống khi app rời foreground/kết thúc và áp dụng lại
  khi quay lại. Android giữ nguyên hành vi chỉ đổi cửa sổ ứng dụng.
- **Vòng đời trình phát**: TV, phim và YouTube tự dừng khi app vào nền/tắt màn
  hình; chỉ tự phát lại khi quay lại nếu trước đó không bị người dùng bấm dừng.
- **Đổi kênh**: dùng "thế hệ" request + dừng/giải phóng controller cũ trước khi
  kết nối kênh mới, xoá video cũ khỏi giao diện ngay — sửa lỗi kênh trước vẫn
  phát tiếp sau khi chuyển kênh.
- **Trình phát phim**: áp dụng cùng cơ chế vòng đời và chống race khi thử lại.

### Loại bỏ
- **Điều khiển bằng giọng nói**: xoá dịch vụ, hộp thoại, công tắc cài đặt,
  quyền `RECORD_AUDIO` (Android), `NSMicrophoneUsageDescription` (iOS) và
  dependency `speech_to_text`. Không còn yêu cầu quyền micro.

### Kiểm thử
- `flutter analyze`: 0 lỗi.
- `flutter test`: 12/12 pass (Home/tab, tìm kênh, parser bảng tin YouTube,
  thời lượng, theme).
- Kiểm tra mạng thực tế: trang tìm kiếm YouTube trả 20 video; lấy được luồng
  phát muxed (kết quả `stream=OK`).

### Chưa kiểm chứng trên thiết bị thật
- Chưa có Android/iOS thật trong môi trường build: chưa xác nhận hình/tiếng,
  độ sáng iOS, xoay màn hình và luồng cập nhật cài đè end-to-end. CI chỉ build
  và chạy kiểm thử tự động.

## [2.0.2] — 2026-11-02

### Sửa lỗi
- **Ký APK bằng khóa phát hành cố định**: trước đây mỗi lần CI build dùng
  debug keystore mới → APK mới không cài đè được lên bản cũ (khác chữ ký),
  đồng thời chặn cập nhật trong app. Nay keystore được lưu trong GitHub Secrets
  (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_PASSWORD`, `KEY_ALIAS`), Gradle
  đọc qua `android/key.properties` (không commit). CI in chứng chỉ APK để kiểm tra.
- Lần đầu nâng cấp từ v2.0.0/v2.0.1 (debug key CI) cần **gỡ ứng dụng một lần**;
  từ v2.0.2 trở đi, các bản sau cài đè/cập nhật bình thường.

## [2.0.1] — 2026-11-02

### Sửa lỗi nghiêm trọng
- **Màn hình xám toàn bộ nội dung**: `buildTheme` chưa đăng ký `OumijiaColors`
  vào `ThemeData.extensions`, khiến mọi `context.c` ném lỗi và Flutter hiển thị
  ErrorWidget xám. Đã đăng ký extension + thêm test hồi quy cho Home và các tab.
- Hero "Tiếp tục xem" tràn 2px trên màn hình hẹp: giảm logo/khoảng cách, nút "Xem".
- Chip trạng thái dài gây tràn trong hero: thêm nhãn ngắn LIVE/CHẬM/OFFLINE/LỖI,
  text co giãn với ellipsis.
- `SwitchListTile` trong mục Cài đặt nằm trên `Container` có nền → chuyển sang
  `Material` để hiện đúng hiệu ứng chạm.
- **Tab YouTube**: sửa `ChannelId` sai, thay API danh sách kênh đã hỏng bằng RSS
  chính thức (`youtube.com/feeds/videos.xml`) + test parse; thêm 3 danh mục kênh
  chính thức đã xác minh (VTV24, Yan News, Yeah1TV, POPS Kids). Luồng phát vẫn
  trích trực tiếp nên không có quảng cáo.

### Kiểm thử
- `flutter test`: 10/10 pass (theme, Home/tab, tìm kênh, RSS YouTube).
- `flutter analyze`: 0 lỗi.

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
