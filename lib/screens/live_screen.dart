import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../services/prefs_service.dart';
import '../ui.dart';
import 'player_screen.dart';

/// Tab TRUYỀN HÌNH — lưới kênh logo to + tên to.
/// Mở tab lần đầu tự phát kênh xem lần cuối (nếu bật tự phát).
class LiveScreen extends StatefulWidget {
  final AppConfig config;

  const LiveScreen({super.key, required this.config});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  bool _autoPlayed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoPlay());
  }

  Future<void> _maybeAutoPlay() async {
    if (_autoPlayed || !PrefsService.autoPlay || widget.config.channels.isEmpty) {
      return;
    }
    _autoPlayed = true;
    final last = widget.config.channels.firstWhere(
      (c) => c.id == PrefsService.lastChannelId,
      orElse: () => widget.config.channels.first,
    );
    if (!mounted) return;
    await _openPlayer(last);
  }

  Future<void> _openPlayer(Channel ch) async {
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PlayerScreen(config: widget.config, channel: ch),
    ));
    if (mounted) setState(() {}); // cập nhật "Đang xem"
  }

  @override
  Widget build(BuildContext context) {
    final channels = widget.config.channels;
    final lastId = PrefsService.lastChannelId;

    return Scaffold(
      body: SafeArea(
        child: channels.isEmpty
            ? const Center(
                child: Text('Chưa có kênh nào trong danh mục.',
                    style: TextStyle(fontSize: 22)))
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 2.2,
                ),
                itemCount: channels.length,
                itemBuilder: (context, i) {
                  final ch = channels[i];
                  final isLast = ch.id == lastId;
                  return _ChannelTile(
                    channel: ch,
                    highlight: isLast,
                    favorite: PrefsService.isFavorite(ch.id),
                    onTap: () => _openPlayer(ch),
                    onLongPress: () async {
                      await PrefsService.toggleFavorite(ch.id);
                      if (mounted) setState(() {});
                    },
                  );
                },
              ),
      ),
    );
  }
}

/// Ô kênh: logo to + tên to, focus viền sáng (remote TV), yêu thích có ngôi sao.
class _ChannelTile extends StatelessWidget {
  final Channel channel;
  final bool highlight;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ChannelTile({
    required this.channel,
    required this.highlight,
    required this.favorite,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final focused = Focus.of(context).hasFocus;
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.space)) {
          onTap();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: Ui.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: focused
                  ? Ui.focusBorder
                  : (highlight ? Ui.accent.withValues(alpha: 0.6) : Colors.transparent),
              width: focused ? 4 : 2,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  channel.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Ui.textPrimary,
                  ),
                ),
              ),
              if (favorite)
                const Icon(Icons.star, color: Ui.accent, size: 28),
            ],
          ),
        ),
      ),
    );
  }
}
