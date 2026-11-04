import 'dart:io';

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../models.dart';
import '../services/brightness_service.dart';
import '../services/prefs_service.dart';
import '../theme/design_system.dart';
import '../theme/theme_controller.dart';
import '../widgets/update_dialog.dart';

/// Tab CÀI ĐẶT — giao diện, độ sáng cửa sổ, trình phát, cập nhật, về app.
/// Mọi thay đổi áp dụng ngay, lưu tại thiết bị.
class SettingsScreen extends StatefulWidget {
  final AppConfig config;

  const SettingsScreen({super.key, required this.config});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late double _fontScale = ThemeController.instance.value.fontScale;
  late double _brightness = BrightnessService.valueCached;
  late bool _brightnessOn = BrightnessService.enabledCached;
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((p) {
      if (!mounted) return;
      setState(() => _version = '${p.version} (${p.buildNumber})');
    });
  }

  String get _sourceLabel {
    switch (widget.config.source) {
      case 'remote':
        return 'GitHub (mới nhất)';
      case 'cache':
        return 'Bản lưu trên máy';
      default:
        return 'Bản đóng gói trong app';
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final theme = ThemeController.instance.value;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final canBrightness = BrightnessService.supported;

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.s, Sp.xl, Sp.xxl + Sp.l),
        children: [
          // ================= GIAO DIỆN =================
          _Section(
            title: 'Giao diện',
            children: [
              _Label('Chế độ hiển thị'),
              const SizedBox(height: Sp.s),
              SegmentedButton<ThemeMode>(
                segments: const [
                  ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined, size: 18),
                      label: Text('Sáng')),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined, size: 18),
                      label: Text('Tối')),
                  ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined, size: 18),
                      label: Text('Hệ thống')),
                ],
                selected: {theme.mode},
                showSelectedIcon: false,
                onSelectionChanged: (sel) async {
                  await ThemeController.instance.setMode(sel.first);
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(height: Sp.l),
              _Label('Màu chủ đạo'),
              const SizedBox(height: Sp.s),
              Wrap(
                spacing: Sp.m,
                runSpacing: Sp.m,
                children: [
                  for (final key in kAccentKeys)
                    _AccentDot(
                      accentKey: key,
                      dark: dark,
                      selected: theme.accentKey == key,
                      onTap: () async {
                        await ThemeController.instance.setAccent(key);
                        if (mounted) setState(() {});
                      },
                    ),
                ],
              ),
              const SizedBox(height: Sp.l),
              Row(
                children: [
                  _Label('Cỡ chữ hiển thị'),
                  const Spacer(),
                  Text('${(_fontScale * 100).round()}%',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: c.accent, fontWeight: FontWeight.w700)),
                ],
              ),
              Slider(
                value: _fontScale,
                min: 0.9,
                max: 1.3,
                divisions: 8,
                label: '${(_fontScale * 100).round()}%',
                onChanged: (v) {
                  setState(() => _fontScale = v);
                  // Áp dụng ngay toàn app (theme rebuild theo controller).
                  ThemeController.instance.setFontScale(v);
                },
              ),
              Row(
                children: [
                  Text('Nhỏ', style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  Text('Lớn', style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
              const SizedBox(height: Sp.m),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.restart_alt, size: 20),
                  label: const Text('Khôi phục mặc định'),
                  onPressed: () async {
                    await ThemeController.instance.resetToDefault();
                    if (!mounted) return;
                    setState(() => _fontScale = 1.0);
                  },
                ),
              ),
            ],
          ),

          // ================= ĐỘ SÁNG =================
          _Section(
            title: 'Độ sáng màn hình',
            children: [
              if (!canBrightness)
                Text(
                  'Thiết bị này không hỗ trợ điều chỉnh độ sáng trong ứng dụng.',
                  style: Theme.of(context).textTheme.bodyMedium,
                )
              else ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _brightnessOn,
                  onChanged: (v) async {
                    await BrightnessService.setEnabled(v);
                    if (mounted) setState(() => _brightnessOn = v);
                  },
                  title: Text('Độ sáng tuỳ chỉnh',
                      style: Theme.of(context).textTheme.bodyLarge),
                  subtitle: Text(
                    Platform.isIOS
                        ? 'Đổi độ sáng khi đang dùng app; tự khôi phục khi rời app.'
                        : 'Chỉ đổi cửa sổ ứng dụng, không ảnh hưởng độ sáng hệ thống.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                if (_brightnessOn) ...[
                  Row(
                    children: [
                      Icon(Icons.brightness_low,
                          size: 18, color: c.textLo),
                      Expanded(
                        child: Slider(
                          value: _brightness,
                          min: 0.05,
                          max: 1.0,
                          divisions: 19,
                          label: '${(_brightness * 100).round()}%',
                          onChanged: (v) => setState(() => _brightness = v),
                          onChangeEnd: (v) => BrightnessService.setValue(v),
                        ),
                      ),
                      Icon(Icons.brightness_high, size: 20, color: c.textHi),
                      const SizedBox(width: Sp.s),
                      SizedBox(
                        width: 42,
                        child: Text(
                          '${(_brightness * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                  color: c.accent,
                                  fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: const Icon(Icons.settings_backup_restore, size: 18),
                      label: const Text('Dùng độ sáng hệ thống'),
                      onPressed: () async {
                        await BrightnessService.reset();
                        if (!mounted) return;
                        setState(() {
                          _brightnessOn = false;
                          _brightness = BrightnessService.defaultValue;
                        });
                      },
                    ),
                  ),
                ],
              ],
            ],
          ),

          // ================= TRÌNH PHÁT & CẬP NHẬT =================
          _Section(
            title: 'Trình phát & cập nhật',
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: PrefsService.autoUpdate,
                onChanged: (v) async {
                  await PrefsService.setAutoUpdate(v);
                  if (mounted) setState(() {});
                },
                title: Text('Tự kiểm tra cập nhật khi mở app',
                    style: Theme.of(context).textTheme.bodyLarge),
                subtitle: Text('Chỉ kiểm tra một lần mỗi lần khởi động',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              const SizedBox(height: Sp.s),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.system_update_alt, size: 20),
                  label: const Text('Kiểm tra cập nhật ngay'),
                  onPressed: () => showUpdateFlow(context),
                ),
              ),
            ],
          ),

          // ================= ĐIỀU KHIỂN TV =================
          _Section(
            title: 'Điều khiển TV',
            children: [
              _HintRow(icon: Icons.keyboard_arrow_up, text: 'Nút lên / xuống: đổi kênh'),
              _HintRow(icon: Icons.check_circle_outline, text: 'Nút OK: dừng / phát'),
              _HintRow(icon: Icons.arrow_back, text: 'Nút Back: thoát trình phát'),
            ],
          ),

          // ================= VỀ ỨNG DỤNG =================
          _Section(
            title: 'Về ứng dụng',
            children: [
              _InfoRow(label: 'Phiên bản', value: _version.isEmpty ? '...' : _version),
              _InfoRow(label: 'Danh mục kênh', value: _sourceLabel),
              _InfoRow(
                  label: 'Số kênh',
                  value: '${widget.config.channels.length} kênh'),
              const SizedBox(height: Sp.s),
              Text(
                'OUMIJIA TV phát nội dung công khai của các đài truyền hình '
                'và nhà cung cấp; ứng dụng không lưu trữ hay phân phối lại video. '
                'Kênh không có nguồn hợp lệ sẽ được đánh dấu và không mở.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Khối cài đặt có tiêu đề + gạch accent.
class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.l),
      child: Material(
        color: c.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.l),
          side: BorderSide(color: c.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(Sp.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 3.5,
                    height: 18,
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: Sp.m),
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
              const SizedBox(height: Sp.m),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.2));
  }
}

/// Chấm màu chủ đạo trong bảng chọn.
class _AccentDot extends StatelessWidget {
  final String accentKey;
  final bool dark;
  final bool selected;
  final VoidCallback onTap;

  const _AccentDot({
    required this.accentKey,
    required this.dark,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final color = accentColor(accentKey, dark);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(Radii.m),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(
                  color: selected ? c.textHi : Colors.transparent,
                  width: 2.5,
                ),
              ),
              child: selected
                  ? Icon(Icons.check,
                      size: 20,
                      color: dark ? Colors.black : Colors.white)
                  : null,
            ),
            const SizedBox(height: Sp.xs),
            SizedBox(
              width: 64,
              child: Text(
                kAccentNames[accentKey] ?? accentKey,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: selected ? c.textHi : c.textLo,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HintRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HintRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.c.textLo),
          const SizedBox(width: Sp.s),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: Sp.m),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: context.c.textHi, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
