# OUMIJIA TV

App xem truyền hình, phim, YouTube **không quảng cáo** — thiết kế cho người lớn tuổi.

## Đặc điểm
- 📺 **Truyền hình trực tuyến**: VTV1–VTV9, ANTV — mở app là xem, không quảng cáo
- 🎬 **Phim**: nguồn ngoài, poster to, dễ chọn
- 🎵 **YouTube có kiểm duyệt**: chỉ danh mục duyệt sẵn, phát không quảng cáo, playlist chạy liên tục
- 🎙️ **Điều khiển & giọng nói tiếng Việt**: hỗ trợ remote TV (D-pad), tìm kiếm "Bật VTV3", "Mở nhạc trữ tình"
- 👵 **UI cho người già**: chữ to, nút to, tương phản cao, không menu lồng sâu

## Nền tảng
Android + iOS (Flutter). Không có bản web.

## Cấu hình nội dung
Toàn bộ kênh/phim/kênh YouTube nằm trong `config/channels.json`.
Sửa file này là cập nhật nội dung cho app — không cần build lại.

## Cấu trúc
```
oumijia_tv/
├── config/channels.json   # Danh mục nội dung (kênh, phim, YouTube)
├── lib/                   # Mã nguồn Flutter
└── README.md
```
