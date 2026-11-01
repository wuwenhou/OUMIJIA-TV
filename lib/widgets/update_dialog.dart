import 'package:flutter/material.dart';

import '../services/update_service.dart';
import '../ui.dart';

/// Hộp thoại cập nhật lớn, chữ to, dành cho người già.
Future<void> showUpdateFlow(BuildContext context) async {
  // 1. Đang kiểm tra
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _CheckingDialog(),
  );

  final info = await UpdateService.checkForUpdate();

  if (!context.mounted) return;
  Navigator.of(context).pop(); // đóng hộp kiểm tra

  if (info == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Bạn đang dùng bản mới nhất. 👍',
          style: TextStyle(fontSize: 20)),
      duration: Duration(seconds: 3),
    ));
    return;
  }

  // 2. Có bản mới → hỏi
  if (!context.mounted) return;
  final want = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateAvailableDialog(info: info),
  );
  if (want != true || !context.mounted) return;

  // 3. Tải + cài đặt
  await _downloadAndInstall(context, info);
}

Future<void> _downloadAndInstall(BuildContext context, UpdateInfo info) async {
  double progress = 0;
  // Hộp thoại tải
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        // Cập nhật progress từ bên ngoài qua ValueNotifier sẽ phức tạp;
        // dùng closure đơn giản: lưu setState vào biến toàn cục tạm.
        _downloadProgress = (p) {
          progress = p;
          setState(() {});
        };
        return _DownloadingDialog(progress: progress);
      },
    ),
  );

  try {
    final file = await UpdateService.downloadApk(info, onProgress: (p) {
      _downloadProgress?.call(p);
    });
    if (!context.mounted) return;
    Navigator.of(context).pop(); // đóng hộp tải
    await UpdateService.installApk(file);
  } catch (e) {
    if (!context.mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Tải cập nhật thất bại: $e',
          style: const TextStyle(fontSize: 20)),
      duration: const Duration(seconds: 4),
    ));
  } finally {
    _downloadProgress = null;
  }
}

// Biến tạm để cập nhật progress từ callback
void Function(double)? _downloadProgress;

class _CheckingDialog extends StatelessWidget {
  const _CheckingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Ui.surface,
      child: const Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Ui.accent),
            SizedBox(height: 20),
            Text('Đang kiểm tra cập nhật...',
                style: TextStyle(fontSize: 24, color: Ui.textPrimary)),
          ],
        ),
      ),
    );
  }
}

class _UpdateAvailableDialog extends StatelessWidget {
  final UpdateInfo info;

  const _UpdateAvailableDialog({required this.info});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Ui.surface,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.system_update, size: 72, color: Ui.accent),
            const SizedBox(height: 16),
            const Text('Có bản mới!',
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Ui.textPrimary)),
            const SizedBox(height: 8),
            Text('Phiên bản ${info.version}${info.sizeText.isEmpty ? '' : '  •  ${info.sizeText}'}',
                style: const TextStyle(fontSize: 22, color: Ui.accent)),
            if (info.releaseNotes.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(
                  child: Text(
                    info.releaseNotes,
                    style: const TextStyle(
                        fontSize: 18, color: Ui.textSecondary),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                    textStyle: const TextStyle(fontSize: 22),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Cập nhật ngay'),
                ),
                const SizedBox(width: 16),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 28, vertical: 16),
                    textStyle: const TextStyle(fontSize: 22),
                  ),
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Để sau'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DownloadingDialog extends StatelessWidget {
  final double progress;

  const _DownloadingDialog({required this.progress});

  @override
  Widget build(BuildContext context) {
    final pct = (progress * 100).clamp(0, 100).toStringAsFixed(0);
    return Dialog(
      backgroundColor: Ui.surface,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Đang tải bản cập nhật...',
                style: TextStyle(fontSize: 24, color: Ui.textPrimary)),
            const SizedBox(height: 20),
            LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              minHeight: 12,
              color: Ui.accent,
              backgroundColor: Ui.bg,
            ),
            const SizedBox(height: 12),
            Text('$pct%',
                style: const TextStyle(fontSize: 22, color: Ui.accent)),
          ],
        ),
      ),
    );
  }
}
