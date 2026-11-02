import 'package:flutter/material.dart';

import '../models.dart';
import '../services/prefs_service.dart';
import '../theme/design_system.dart';
import '../widgets/channel_card.dart';
import 'player_screen.dart';

/// Màn KÊNH YÊU THÍCH — danh sách đã đánh dấu; nút trái tim để bỏ lưu.
/// Lưu tại thiết bị (shared_preferences), mở lại app vẫn còn.
class FavoritesScreen extends StatefulWidget {
  final AppConfig config;

  const FavoritesScreen({super.key, required this.config});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<Channel> get _items => widget.config.channels
      .where((ch) => PrefsService.isFavorite(ch.id))
      .toList();

  Future<void> _remove(Channel ch) async {
    await PrefsService.toggleFavorite(ch.id);
    if (mounted) setState(() {});
  }

  Future<void> _open(Channel ch) async {
    if (ch.unavailable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${ch.name}: ${statusLabel(ch.health)}.'),
      ));
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PlayerScreen(config: widget.config, channel: ch),
    ));
    // Trong player có thể đã thêm/bỏ yêu thích → nạp lại danh sách.
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;

    return Scaffold(
      appBar: AppBar(
        title: Text('Kênh yêu thích'
            '${items.isEmpty ? '' : ' (${items.length})'}'),
      ),
      body: items.isEmpty
          ? _EmptyFavorites()
          : ListView.separated(
              padding: const EdgeInsets.all(Sp.xl),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: Sp.s + 2),
              itemBuilder: (context, i) {
                final ch = items[i];
                return Row(
                  children: [
                    Expanded(
                      child: ChannelCard(
                        channel: ch,
                        favorite: true,
                        onTap: () => _open(ch),
                        onLongPress: () => _remove(ch),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Bỏ khỏi yêu thích',
                      onPressed: () => _remove(ch),
                      icon: Icon(Icons.heart_broken_outlined,
                          color: context.c.textMed),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _EmptyFavorites extends StatelessWidget {
  const _EmptyFavorites();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.favorite_outline, size: 52, color: c.textLo),
            const SizedBox(height: Sp.m),
            Text('Chưa có kênh yêu thích nào',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Sp.xs),
            Text(
              'Mở một kênh rồi bấm nút ♥ trong trình phát, '
              'hoặc giữ lâu (long-press) một ô kênh trong tab Kênh.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
