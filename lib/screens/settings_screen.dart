import 'package:flutter/material.dart';

import '../services/prefs_service.dart';
import '../ui.dart';

/// Tab CÀI ĐẶT — tối giản: cỡ chữ, tự phát, giọng nói.
class SettingsScreen extends StatefulWidget {
  final VoidCallback onChanged;

  const SettingsScreen({super.key, required this.onChanged});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 8),
        const Text('Cài đặt',
            style: TextStyle(
                fontSize: 34, fontWeight: FontWeight.bold, color: Ui.textPrimary)),
        const SizedBox(height: 24),

        // ---- Cỡ chữ ----
        _SectionCard(
          title: 'Cỡ chữ',
          child: Row(
            children: [
              _FontChip(label: 'Vừa', value: 1.0),
              const SizedBox(width: 12),
              _FontChip(label: 'To', value: 1.2),
              const SizedBox(width: 12),
              _FontChip(label: 'Rất to', value: 1.4),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ---- Tự phát khi mở app ----
        _SectionCard(
          title: 'Mở app là xem ngay',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: PrefsService.autoPlay,
            onChanged: (v) {
              PrefsService.setAutoPlay(v);
              setState(() {});
            },
            activeColor: Ui.accent,
            title: const Text('Tự bật kênh xem lần cuối',
                style: TextStyle(fontSize: 22, color: Ui.textPrimary)),
          ),
        ),
        const SizedBox(height: 16),

        // ---- Giọng nói ----
        _SectionCard(
          title: 'Giọng nói',
          child: SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: PrefsService.voiceEnabled,
            onChanged: (v) {
              PrefsService.setVoiceEnabled(v);
              setState(() {});
            },
            activeColor: Ui.accent,
            title: const Text('Bật điều khiển bằng giọng nói',
                style: TextStyle(fontSize: 22, color: Ui.textPrimary)),
            subtitle: const Text(
                'Nói: "Bật VTV3", "Mở nhạc trữ tình"',
                style: TextStyle(fontSize: 18, color: Ui.textSecondary)),
          ),
        ),
        const SizedBox(height: 16),

        // ---- Hướng dẫn remote ----
        const _SectionCard(
          title: 'Dùng điều khiển TV',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('• Nút lên / xuống: đổi kênh',
                  style: TextStyle(fontSize: 20, color: Ui.textPrimary)),
              SizedBox(height: 8),
              Text('• Nút OK: dừng / phát',
                  style: TextStyle(fontSize: 20, color: Ui.textPrimary)),
              SizedBox(height: 8),
              Text('• Nút Back: thoát',
                  style: TextStyle(fontSize: 20, color: Ui.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _FontChip extends StatelessWidget {
  final String label;
  final double value;

  const _FontChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final selected = (PrefsService.fontScale - value).abs() < 0.01;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          PrefsService.setFontScale(value);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Đã đổi cỡ chữ',
                  style: TextStyle(fontSize: 20))));
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: selected ? Ui.accent : Ui.bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: selected ? Ui.accent : Ui.textSecondary, width: 2),
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    fontSize: 20 * value,
                    fontWeight: FontWeight.bold,
                    color: selected ? Colors.black : Ui.textPrimary)),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Ui.surface,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Ui.accent)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
