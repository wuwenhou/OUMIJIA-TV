import 'package:flutter/material.dart';

import '../models.dart';
import '../services/config_service.dart';
import '../services/prefs_service.dart';
import '../theme/design_system.dart';
import '../widgets/channel_card.dart';
import 'favorites_screen.dart';
import 'player_screen.dart';

/// Tab KÊNH — danh sách dọc đơn giản + kéo-làm-mới cấu hình từ GitHub
/// (cập nhật danh mục không cần phát hành APK mới).
class ChannelsScreen extends StatefulWidget {
  final AppConfig config;
  final void Function(AppConfig config)? onConfigChanged;

  const ChannelsScreen({super.key, required this.config, this.onConfigChanged});

  @override
  State<ChannelsScreen> createState() => _ChannelsScreenState();
}

class _ChannelsScreenState extends State<ChannelsScreen> {
  bool _reloadBusy = false;

  /// Kênh yêu thích luôn lên đầu, giữ nguyên thứ tự gốc của các kênh còn lại.
  List<Channel> get _filtered {
    final favorites = <Channel>[];
    final others = <Channel>[];
    for (final channel in widget.config.channels) {
      if (PrefsService.isFavorite(channel.id)) {
        favorites.add(channel);
      } else {
        others.add(channel);
      }
    }
    return [...favorites, ...others];
  }

  Future<void> _reload() async {
    if (_reloadBusy) return;
    setState(() => _reloadBusy = true);
    try {
      final cfg = await ConfigService.load();
      widget.onConfigChanged?.call(cfg);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_sourceLabel(cfg.source)),
          duration: const Duration(seconds: 2),
        ));
      }
    } finally {
      if (mounted) setState(() => _reloadBusy = false);
    }
  }

  String _sourceLabel(String source) {
    switch (source) {
      case 'remote':
        return 'Đã cập nhật danh mục từ GitHub';
      case 'cache':
        return 'Dùng bản lưu gần nhất (không có mạng)';
      default:
        return 'Dùng bản kênh đóng gói trong app';
    }
  }

  void _open(Channel ch) {
    if (ch.unavailable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${ch.name}: ${statusLabel(ch.health)}. '
            'Kênh này chưa có nguồn phát hợp lệ.'),
      ));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PlayerScreen(config: widget.config, channel: ch),
    ));
  }

  Future<void> _toggleFavorite(Channel ch) async {
    await PrefsService.toggleFavorite(ch.id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final items = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kênh truyền hình'),
        actions: [
          IconButton(
            tooltip: 'Kênh yêu thích',
            icon: const Icon(Icons.favorite_border_rounded),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => FavoritesScreen(config: widget.config),
              ));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ---- số kênh ----
          Padding(
            padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.s, Sp.xl, Sp.s),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 2,
              children: [
                Text('${items.length} kênh',
                    style: Theme.of(context).textTheme.bodySmall),
                Text('Kéo xuống để làm mới',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: c.textLo)),
              ],
            ),
          ),
          // ---- danh sách dọc ----
          Expanded(
            child: RefreshIndicator(
              onRefresh: _reload,
              child: items.isEmpty
                  ? const _EmptyState()
                  : ListView.separated(
                      padding:
                          const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, Sp.xxl + Sp.l),
                      itemCount: items.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: Sp.s + 2),
                      itemBuilder: (context, i) {
                        final ch = items[i];
                        return ChannelCard(
                          channel: ch,
                          favorite: PrefsService.isFavorite(ch.id),
                          onTap: () => _open(ch),
                          onLongPress: () => _toggleFavorite(ch),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Chưa có kênh nào trong danh mục cấu hình.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.tv_outlined, size: 46, color: c.textLo),
          const SizedBox(height: Sp.m),
          Text('Chưa có kênh', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Sp.xs),
          Text('Kéo xuống để làm mới cấu hình.',
              style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
