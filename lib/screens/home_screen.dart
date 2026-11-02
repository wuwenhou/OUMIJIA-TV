import 'package:flutter/material.dart';

import '../models.dart';
import '../services/prefs_service.dart';
import '../theme/design_system.dart';
import '../widgets/channel_card.dart';
import '../widgets/update_dialog.dart';
import 'channels_screen.dart';
import 'favorites_screen.dart';
import 'movies_screen.dart';
import 'player_screen.dart';
import 'settings_screen.dart';
import 'youtube_screen.dart';

/// Màn hình chính — 5 tab: Home · Kênh · Phim · YouTube · Cài đặt.
/// Home: hero "Tiếp tục xem" + hàng yêu thích + vừa xem + toàn bộ kênh.
class HomeScreen extends StatefulWidget {
  final AppConfig config;

  const HomeScreen({super.key, required this.config});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  late AppConfig _config = widget.config;

  @override
  void initState() {
    super.initState();
    if (PrefsService.autoUpdate) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await checkAndShowUpdate(context);
      });
    }
  }

  Future<void> _openPlayer(Channel ch) async {
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PlayerScreen(config: _config, channel: ch),
    ));
    // Trong player có thể đổi kênh / yêu thích → Home nạp lại dữ liệu.
    if (mounted) setState(() {});
  }

  void _play(Channel ch) {
    if (ch.unavailable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${ch.name}: ${statusLabel(ch.health)}. '
            'Kênh này chưa có nguồn phát hợp lệ.'),
      ));
      return;
    }
    _openPlayer(ch);
  }

  Future<void> _toggleFavorite(Channel ch) async {
    final adding = !PrefsService.isFavorite(ch.id);
    await PrefsService.toggleFavorite(ch.id);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(adding
          ? 'Đã lưu ${ch.name} vào yêu thích'
          : 'Đã bỏ ${ch.name} khỏi yêu thích'),
      duration: const Duration(milliseconds: 1500),
    ));
  }

  Future<void> _openFavorites() async {
    await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => FavoritesScreen(config: _config)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final destinations = const [
      NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Trang chủ'),
      NavigationDestination(
          icon: Icon(Icons.tv_outlined),
          selectedIcon: Icon(Icons.tv),
          label: 'Kênh'),
      NavigationDestination(
          icon: Icon(Icons.movie_outlined),
          selectedIcon: Icon(Icons.movie),
          label: 'Phim'),
      NavigationDestination(
          icon: Icon(Icons.smart_display_outlined),
          selectedIcon: Icon(Icons.smart_display),
          label: 'YouTube'),
      NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          selectedIcon: Icon(Icons.settings),
          label: 'Cài đặt'),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          _HomeTab(
            config: _config,
            onPlay: _play,
            onToggleFavorite: (ch) => _toggleFavorite(ch),
            onGoChannels: () => setState(() => _tab = 1),
            onOpenFavorites: _openFavorites,
            onConfigChanged: (cfg) => setState(() => _config = cfg),
          ),
          ChannelsScreen(
            config: _config,
            onConfigChanged: (cfg) => setState(() => _config = cfg),
          ),
          MoviesScreen(config: _config),
          YouTubeScreen(config: _config),
          SettingsScreen(config: _config),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: destinations,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}

/// Tab Home (thân app, không điều hướng ra ngoài).
class _HomeTab extends StatelessWidget {
  final AppConfig config;
  final void Function(Channel) onPlay;
  final void Function(Channel) onToggleFavorite;
  final VoidCallback onGoChannels;
  final VoidCallback onOpenFavorites;
  final void Function(AppConfig) onConfigChanged;

  const _HomeTab({
    required this.config,
    required this.onPlay,
    required this.onToggleFavorite,
    required this.onGoChannels,
    required this.onOpenFavorites,
    required this.onConfigChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    Channel? byId(String id) {
      for (final ch in config.channels) {
        if (ch.id == id) return ch;
      }
      return null;
    }

    final hero = byId(PrefsService.lastChannelId) ??
        (config.channels.isEmpty ? null : config.channels.first);
    final favorites =
        config.channels.where((ch) => PrefsService.isFavorite(ch.id)).toList();
    final recent = PrefsService.recentChannelIds
        .map(byId)
        .whereType<Channel>()
        .where((ch) => ch.id != hero?.id)
        .take(6)
        .toList();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          toolbarHeight: 76,
          titleSpacing: Sp.xl,
          title: Row(
            children: [
              const BrandBadge(),
              const SizedBox(width: Sp.m),
              Text('OUMIJIA TV',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(letterSpacing: 0.4)),
            ],
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: Sp.m),
              child: IconButton(
                tooltip: 'Kênh yêu thích',
                onPressed: onOpenFavorites,
                icon: Badge(
                  isLabelVisible: favorites.isNotEmpty,
                  label: Text('${favorites.length}'),
                  backgroundColor: c.accent,
                  textColor: Colors.black,
                  smallSize: 16,
                  child: const Icon(Icons.favorite_border),
                ),
              ),
            ),
          ],
        ),
        if (config.channels.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(Sp.xxl),
              child: Text(
                'Danh mục kênh đang trống. '
                'Thêm kênh vào config/channels.json trên GitHub rồi kéo làm mới tab Kênh.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
        else ...[
          // ---- hero Tiếp tục xem ----
          if (hero != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.s, Sp.xl, 0),
              sliver: SliverToBoxAdapter(
                child: ContinueWatchingCard(channel: hero, onPlay: () => onPlay(hero)),
              ),
            ),
          // ---- yêu thích ----
          if (favorites.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.xl, Sp.xl, 0),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Kênh yêu thích',
                  trailing: IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 20),
                    tooltip: 'Mở danh sách yêu thích',
                    onPressed: onOpenFavorites,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
              sliver: SliverToBoxAdapter(
                child: MiniChannelRow(
                  channels: favorites.take(8).toList(),
                  onOpen: onPlay,
                ),
              ),
            ),
          ],
          // ---- vừa xem ----
          if (recent.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.xl, Sp.xl, 0),
              sliver: SliverToBoxAdapter(child: SectionHeader(title: 'Vừa xem')),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
              sliver: SliverToBoxAdapter(
                child: MiniChannelRow(channels: recent, onOpen: onPlay),
              ),
            ),
          ],
          // ---- tất cả kênh ----
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.xl, Sp.xl, 0),
            sliver: SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Tất cả kênh truyền hình',
                trailing:
                    TextButton(onPressed: onGoChannels, child: const Text('Xem tất cả')),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, 0),
            sliver: SliverList.separated(
              itemCount: config.channels.length,
              itemBuilder: (context, i) {
                final ch = config.channels[i];
                return ChannelCard(
                  channel: ch,
                  favorite: PrefsService.isFavorite(ch.id),
                  onTap: () => onPlay(ch),
                  onLongPress: () => onToggleFavorite(ch),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: Sp.s + 2),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: Sp.xxl + Sp.l)),
        ],
      ],
    );
  }
}

/// Hero "Tiếp tục xem": gradient accent, logo + tên lớn, chip trạng thái LIVE.
class ContinueWatchingCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback onPlay;

  const ContinueWatchingCard({super.key, required this.channel, required this.onPlay});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.l),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.accent.withValues(alpha: 0.18), c.surfaceAlt],
        ),
        border: Border.all(color: c.accent.withValues(alpha: 0.35)),
      ),
      padding: const EdgeInsets.all(Sp.xl),
      child: Row(
        children: [
          ChannelLogo(channel: channel, size: 64),
          const SizedBox(width: Sp.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('TIẾP TỤC XEM',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: c.accent,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w800)),
                const SizedBox(height: Sp.xs),
                Text(channel.name,
                    style: Theme.of(context).textTheme.headlineMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: Sp.xs + 2),
                StatusChip(
                  text: statusLabel(channel.health).toUpperCase(),
                  color: statusColor(context, channel.health),
                  pulsing: channel.health == 'WORKING',
                ),
              ],
            ),
          ),
          const SizedBox(width: Sp.m),
          FilledButton.icon(
            onPressed: channel.unavailable ? null : onPlay,
            icon: const Icon(Icons.play_arrow_rounded, size: 26),
            label: const Text('Xem ngay'),
          ),
        ],
      ),
    );
  }
}

/// Hàng chip nhỏ: logo + tên kênh, bấm để mở trình phát.
class MiniChannelRow extends StatelessWidget {
  final List<Channel> channels;
  final void Function(Channel) onOpen;

  const MiniChannelRow({super.key, required this.channels, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final ch in channels)
            Padding(
              padding: const EdgeInsets.only(right: Sp.m),
              child: Material(
                color: c.surface,
                borderRadius: BorderRadius.circular(Radii.xl),
                child: InkWell(
                  borderRadius: BorderRadius.circular(Radii.xl),
                  onTap: () => onOpen(ch),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(Sp.s + 2, Sp.s, Sp.l + 2, Sp.s),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.xl),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        ChannelLogo(channel: ch, size: 32),
                        const SizedBox(width: Sp.s + 4),
                        Text(ch.name, style: Theme.of(context).textTheme.labelLarge),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Logo chữ "OUMIJIA" vuông gradient accent trên app bar.
class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.m),
        gradient: LinearGradient(colors: [c.accent, c.accent.withValues(alpha: 0.68)]),
      ),
      child: const Icon(Icons.smart_display, color: Colors.black, size: 24),
    );
  }
}
