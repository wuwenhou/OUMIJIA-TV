import 'package:flutter/material.dart';

import '../services/prefs_service.dart';
import '../ui.dart';
import '../widgets/update_dialog.dart';

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
                fontSize: 20, fontWeight: FontWeight.bold, color: Ui.textPrimary)),
        const SizedBox(height: 24),

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
            activeThumbColor: Ui.accent,
            title: const Text('Bật điều khiển bằng giọng nói',
                style: TextStyle(fontSize: 16, color: Ui.textPrimary)),
            subtitle: const Text(
                'Nói: "Bật VTV3", "Mở nhạc trữ tình"',
                style: TextStyle(fontSize: 18, color: Ui.textSecondary)),
          ),
        ),
        const SizedBox(height: 16),

        // ---- Cập nhật ----
        _SectionCard(
          title: 'Cập nhật',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: PrefsService.autoUpdate,
                onChanged: (v) {
                  PrefsService.setAutoUpdate(v);
                  setState(() {});
                },
                activeThumbColor: Ui.accent,
                title: const Text('Tự kiểm tra khi mở app',
                    style: TextStyle(fontSize: 16, color: Ui.textPrimary)),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.system_update, size: 28),
                  label: const Text('Kiểm tra cập nhật ngay',
                      style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () => showUpdateFlow(context),
                ),
              ),
            ],
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
                    fontSize: 16,
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
