import 'package:cached_network_image/cached_network_image.dart';
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
/// Home giới thiệu 3 khu vực theo thứ tự: Truyền hình → Phim → YouTube.
class HomeScreen extends StatefulWidget {
  final AppConfig config;

  const HomeScreen({super.key, required this.config});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  late AppConfig _config = widget.config;

  /// Chỉ dựng tab khi người dùng mở lần đầu — tránh gọi mạng YouTube,
  /// đọc PackageInfo... ngay lúc khởi động.
  final Set<int> _visited = {0};

  void _selectTab(int index) {
    setState(() {
      _tab = index;
      _visited.add(index);
    });
  }

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
            onGoChannels: () => _selectTab(1),
            onGoMovies: () => _selectTab(2),
            onGoYouTube: () => _selectTab(3),
            onOpenFavorites: _openFavorites,
          ),
          _visited.contains(1)
              ? ChannelsScreen(
                  config: _config,
                  onConfigChanged: (cfg) => setState(() => _config = cfg),
                )
              : const SizedBox.shrink(),
          _visited.contains(2)
              ? MoviesScreen(config: _config)
              : const SizedBox.shrink(),
          _visited.contains(3)
              ? YouTubeScreen(config: _config)
              : const SizedBox.shrink(),
          _visited.contains(4)
              ? SettingsScreen(config: _config)
              : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _selectTab,
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
  final VoidCallback onGoChannels;
  final VoidCallback onGoMovies;
  final VoidCallback onGoYouTube;
  final VoidCallback onOpenFavorites;

  const _HomeTab({
    required this.config,
    required this.onPlay,
    required this.onGoChannels,
    required this.onGoMovies,
    required this.onGoYouTube,
    required this.onOpenFavorites,
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
    final favoriteIds = favorites.map((ch) => ch.id).toSet();
    final others = config.channels
        .where((ch) => ch.id != hero?.id && !favoriteIds.contains(ch.id))
        .take(8)
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

        // ==================== 1. TRUYỀN HÌNH ====================
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.s, Sp.xl, 0),
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Truyền hình',
              trailing: TextButton(
                onPressed: onGoChannels,
                child: const Text('Xem tất cả'),
              ),
            ),
          ),
        ),
        if (config.channels.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, 0),
            sliver: SliverToBoxAdapter(
              child: _EmptyCard(
                icon: Icons.tv_off_outlined,
                title: 'Danh mục kênh đang trống',
                message: 'Thêm kênh vào config/channels.json trên GitHub '
                    'rồi kéo làm mới tab Kênh.',
                actionLabel: 'Mở tab Kênh',
                onAction: onGoChannels,
              ),
            ),
          )
        else ...[
          if (hero != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, 0),
              sliver: SliverToBoxAdapter(
                child: ContinueWatchingCard(
                    channel: hero, onPlay: () => onPlay(hero)),
              ),
            ),
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
          if (others.isNotEmpty) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.xl, Sp.xl, 0),
              sliver: SliverToBoxAdapter(
                child: SectionHeader(
                  title: 'Kênh nổi bật',
                  trailing: IconButton(
                    icon: const Icon(Icons.arrow_forward, size: 20),
                    tooltip: 'Mở toàn bộ kênh',
                    onPressed: onGoChannels,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
              sliver: SliverToBoxAdapter(
                child: MiniChannelRow(channels: others, onOpen: onPlay),
              ),
            ),
          ],
        ],

        // ==================== 2. PHIM ====================
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.xxl, Sp.xl, 0),
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              title: 'Phim',
              trailing: TextButton(
                onPressed: onGoMovies,
                child: const Text('Xem tất cả'),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.xl),
          sliver: SliverToBoxAdapter(
            child: config.movies.isEmpty
                ? _EmptyCard(
                    icon: Icons.movie_outlined,
                    title: 'Kho phim đang trống',
                    message: 'Khi chủ ứng dụng thêm phim hợp lệ vào cấu hình, '
                        'phim sẽ xuất hiện tại đây và trong tab Phim.',
                    actionLabel: 'Mở tab Phim',
                    onAction: onGoMovies,
                  )
                : _HomeMovieRow(movies: config.movies.take(10).toList()),
          ),
        ),

        // ==================== 3. YOUTUBE ====================
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.xxl, Sp.xl, 0),
          sliver: SliverToBoxAdapter(
            child: SectionHeader(
              title: 'YouTube',
              trailing: TextButton(
                onPressed: onGoYouTube,
                child: const Text('Mở'),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Sp.xl, 0, Sp.xl, 0),
          sliver: SliverToBoxAdapter(
            child: _YouTubePromoCard(onOpen: onGoYouTube),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: Sp.xxl + Sp.l)),
      ],
    );
  }
}

/// Hàng poster phim trên Home — bấm để phát ngay.
class _HomeMovieRow extends StatelessWidget {
  final List<MovieItem> movies;

  const _HomeMovieRow({required this.movies});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return SizedBox(
      height: 246,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: movies.length,
        separatorBuilder: (_, __) => const SizedBox(width: Sp.m),
        itemBuilder: (context, i) {
          final movie = movies[i];
          return SizedBox(
            width: 132,
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.m),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  fullscreenDialog: true,
                  builder: (_) => MoviePlayerScreen(movie: movie),
                ));
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(Radii.m),
                    child: AspectRatio(
                      aspectRatio: 2 / 3,
                      child: movie.poster.isEmpty
                          ? Container(
                              color: c.surfaceAlt,
                              child: Icon(Icons.movie_outlined,
                                  size: 34, color: c.textLo),
                            )
                          : CachedNetworkImage(
                              imageUrl: movie.poster,
                              fit: BoxFit.cover,
                              placeholder: (_, __) =>
                                  Container(color: c.surfaceAlt),
                              errorWidget: (_, __, ___) => Container(
                                color: c.surfaceAlt,
                                child: Icon(Icons.broken_image_outlined,
                                    size: 30, color: c.textLo),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: Sp.s),
                  Text(
                    movie.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: c.textHi,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Thẻ giới thiệu YouTube trên Home (không gọi mạng).
class _YouTubePromoCard extends StatelessWidget {
  final VoidCallback onOpen;

  const _YouTubePromoCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(Sp.l),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Radii.l),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [c.accent.withValues(alpha: 0.14), c.surfaceAlt],
        ),
        border: Border.all(color: c.accent.withValues(alpha: 0.32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(Radii.m),
                ),
                child: Icon(Icons.smart_display, color: c.accent, size: 26),
              ),
              const SizedBox(width: Sp.m),
              Expanded(
                child: Text(
                  'Video YouTube không quảng cáo',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: Sp.s),
          Text(
            'Bảng tin video theo chủ đề, tìm kiếm tự do và phát trực tiếp '
            'không qua quảng cáo.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Sp.m),
          Wrap(
            spacing: Sp.s,
            runSpacing: Sp.s,
            children: const [
              _FeatureChip(icon: Icons.search_rounded, label: 'Tìm kiếm'),
              _FeatureChip(icon: Icons.category_outlined, label: 'Chủ đề'),
              _FeatureChip(icon: Icons.block_rounded, label: 'Không quảng cáo'),
            ],
          ),
          const SizedBox(height: Sp.m),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.play_arrow_rounded, size: 22),
              label: const Text('Khám phá'),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.s + 2, vertical: 5),
      decoration: BoxDecoration(
        color: c.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(Radii.xl),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: c.textMed),
          const SizedBox(width: 5),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      padding: const EdgeInsets.all(Sp.l),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.m),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 34, color: c.textLo),
          const SizedBox(width: Sp.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(message, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: Sp.s),
          TextButton(onPressed: onAction, child: Text(actionLabel)),
        ],
      ),
    );
  }
}

/// Hero "Tiếp tục xem": gradient accent, logo + tên lớn, chip trạng thái LIVE.
class ContinueWatchingCard extends StatelessWidget {
  final Channel channel;
  final VoidCallback onPlay;

  const ContinueWatchingCard(
      {super.key, required this.channel, required this.onPlay});

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
      padding: const EdgeInsets.all(Sp.l),
      child: Row(
        children: [
          ChannelLogo(channel: channel, size: 56),
          const SizedBox(width: Sp.m),
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
                  text: statusShortLabel(channel.health),
                  color: statusColor(context, channel.health),
                  pulsing: channel.health == 'WORKING',
                ),
              ],
            ),
          ),
          const SizedBox(width: Sp.m),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onPressed: channel.unavailable ? null : onPlay,
            icon: const Icon(Icons.play_arrow_rounded, size: 24),
            label: const Text('Xem'),
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

  const MiniChannelRow(
      {super.key, required this.channels, required this.onOpen});

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
                    padding: const EdgeInsets.fromLTRB(
                        Sp.s + 2, Sp.s, Sp.l + 2, Sp.s),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(Radii.xl),
                      border: Border.all(color: c.border),
                    ),
                    child: Row(
                      children: [
                        ChannelLogo(channel: ch, size: 32),
                        const SizedBox(width: Sp.s + 4),
                        Text(ch.name,
                            style:
                                Theme.of(context).textTheme.labelLarge),
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
        gradient:
            LinearGradient(colors: [c.accent, c.accent.withValues(alpha: 0.68)]),
      ),
      child: const Icon(Icons.smart_display, color: Colors.black, size: 24),
    );
  }
}
