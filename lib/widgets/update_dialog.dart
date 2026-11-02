import 'package:flutter/material.dart';

import '../services/update_service.dart';
import '../theme/design_system.dart';

/// Luồng cập nhật trong app (bản APK độc lập → GitHub Releases):
/// - [checkAndShowUpdate] : kiểm tra thầm lặng khi mở app, có bản mới mới hỏi.
/// - [showUpdateFlow]     : có hộp "Đang kiểm tra" + thông báo kết quả
///                          (dùng cho nút "Kiểm tra cập nhật ngay" ở Cài đặt).
///
/// Tải về qua UpdateService, cài đặt nhờ trình cài Android (OpenFilex) —
/// người dùng vẫn phải xác nhận cài đặt như Android yêu cầu.
Future<void> checkAndShowUpdate(BuildContext context) async {
  final info = await UpdateService.checkForUpdate();
  if (info == null || !context.mounted) return;
  final want = await _askUpdate(context, info);
  if (want == true && context.mounted) await _downloadAndInstall(context, info);
}

Future<void> showUpdateFlow(BuildContext context) async {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _CheckingDialog(),
  );

  final info = await UpdateService.checkForUpdate();

  if (!context.mounted) return;
  Navigator.of(context).pop(); // đóng hộp đang kiểm tra

  if (info == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Bạn đang dùng bản mới nhất.'),
      duration: Duration(seconds: 2),
    ));
    return;
  }

  final want = await _askUpdate(context, info);
  if (want == true && context.mounted) await _downloadAndInstall(context, info);
}

Future<bool?> _askUpdate(BuildContext context, UpdateInfo info) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _UpdateAvailableDialog(info: info),
  );
}

Future<void> _downloadAndInstall(BuildContext context, UpdateInfo info) async {
  double progress = 0;
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        // Callback từ UpdateService gọi lại setState của hộp thoại này.
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
      content: Text('Tải bản cập nhật thất bại: $e'),
      duration: const Duration(seconds: 4),
    ));
  } finally {
    _downloadProgress = null;
  }
}

// Nối callback tiến trình từ UpdateService vào hộp thoại đang mở.
void Function(double)? _downloadProgress;

class _CheckingDialog extends StatelessWidget {
  const _CheckingDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: Sp.l),
            Text('Đang kiểm tra bản mới...',
                style: Theme.of(context).textTheme.bodyLarge),
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
      child: Padding(
        padding: const EdgeInsets.all(Sp.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.m),
                color: context.c.accent.withValues(alpha: 0.16),
              ),
              child:
                  Icon(Icons.system_update_alt, color: context.c.accent, size: 28),
            ),
            const SizedBox(height: Sp.l),
            Text('Có bản mới', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: Sp.xs),
            Text(
              'Phiên bản ${info.version}'
              '${info.sizeText.isEmpty ? '' : '  •  ${info.sizeText}'}',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.c.accent, fontWeight: FontWeight.w600),
            ),
            if (info.releaseNotes.trim().isNotEmpty) ...[
              const SizedBox(height: Sp.l),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 180),
                child: SingleChildScrollView(
                  child: Text(info.releaseNotes,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
              ),
            ],
            const SizedBox(height: Sp.xl),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Cập nhật ngay'),
                  ),
                ),
                const SizedBox(width: Sp.m),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Để sau'),
                  ),
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
      child: Padding(
        padding: const EdgeInsets.all(Sp.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Đang tải bản cập nhật...',
                style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: Sp.l),
            LinearProgressIndicator(
              value: progress > 0 ? progress : null,
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: Sp.s),
            Text(
              progress > 0 ? '$pct%' : 'Đang kết nối...',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: context.c.accent),
            ),
          ],
        ),
      ),
    );
  }
}
