import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models.dart';
import '../services/youtube_service.dart';
import '../theme/design_system.dart';

/// Tab YOUTUBE — chỉ danh mục đã duyệt, phát không quảng cáo,
/// playlist chạy liên tục (hết bài tự chuyển, lỗi tự nhảy).
class YouTubeScreen extends StatefulWidget {
  final AppConfig config;

  const YouTubeScreen({super.key, required this.config});

  @override
  State<YouTubeScreen> createState() => _YouTubeScreenState();
}

class _YouTubeScreenState extends State<YouTubeScreen> {
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cats = widget.config.youtubeCategories;

    return Scaffold(
      appBar: AppBar(title: const Text('YouTube')),
      body: cats.isEmpty
          ? _EmptyYouTube()
          : ListView(
              padding:
                  const EdgeInsets.fromLTRB(Sp.xl, Sp.s, Sp.xl, Sp.xxl + Sp.l),
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_outlined, size: 16, color: c.accent),
                    const SizedBox(width: Sp.s),
                    Expanded(
                      child: Text(
                        'Danh mục đã chọn lọc — phát liên tục, không quảng cáo.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Sp.l),
                for (final cat in cats)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Sp.m),
                    child: _CategoryTile(category: cat),
                  ),
              ],
            ),
    );
  }
}

class _EmptyYouTube extends StatelessWidget {
  const _EmptyYouTube();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.smart_display_outlined, size: 52, color: c.textLo),
            const SizedBox(height: Sp.m),
            Text('Chưa có danh mục YouTube',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Sp.xs),
            Text(
              'Thêm danh mục và kênh YouTube đã duyệt vào config/channels.json '
              'trên GitHub — app tự cập nhật khi mở lại hoặc kéo làm mới tab Kênh.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final YouTubeCategory category;

  const _CategoryTile({required this.category});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(Radii.l),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.l),
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => _CategoryPlayerScreen(category: category),
          ));
        },
        child: Container(
          padding: const EdgeInsets.all(Sp.l),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.l),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Radii.m),
                  color: c.accent.withValues(alpha: 0.14),
                ),
                child: Center(
                  child: Text(category.icon,
                      style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: Sp.l),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${category.channels.length} kênh đã duyệt',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accent.withValues(alpha: 0.12),
                ),
                child: Icon(Icons.play_arrow_rounded,
                    color: c.accent, size: 24),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Phát liên tục các video mới nhất của các kênh trong danh mục.
class _CategoryPlayerScreen extends StatefulWidget {
  final YouTubeCategory category;

  const _CategoryPlayerScreen({required this.category});

  @override
  State<_CategoryPlayerScreen> createState() => _CategoryPlayerScreenState();
}

class _CategoryPlayerScreenState extends State<_CategoryPlayerScreen> {
  ContinuousPlaylist? _playlist;
  VideoPlayerController? _controller;
  String _status = 'Đang lấy danh sách...';
  String _nowTitle = '';
  bool _busy = false;

  static const _accent = Color(0xFFFFC93C);

  bool get _loadFailed => _status.contains('Không lấy được');

  @override
  void initState() {
    super.initState();
    _loadPlaylist();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadPlaylist() async {
    setState(() => _status = 'Đang lấy danh sách...');
    final videos = <Video>[];
    for (final ch in widget.category.channels) {
      try {
        final list =
            await YouTubeService.channelVideos(ch.channelId, limit: 20);
        videos.addAll(list);
      } catch (_) {
        // Kênh lỗi → bỏ qua, lấy kênh khác
      }
    }
    if (videos.isEmpty) {
      setState(() =>
          _status = 'Không lấy được danh sách. Kiểm tra mạng rồi thử lại.');
      return;
    }
    // Xáo trộn nhẹ để không dồn 1 kênh, nhưng giữ ~mới nhất
    final sorted = videos.toList()
      ..sort((a, b) =>
          b.uploadDate?.compareTo(a.uploadDate ?? DateTime(2000)) ?? 0);
    final picked = <Video>[];
    var round = 0;
    while (picked.length < 50 && round < 20) {
      var added = false;
      for (final v in sorted) {
        if (picked.length >= 50) break;
        if (round == 0 || sorted.indexOf(v) % (round + 1) == round) {
          if (!picked.contains(v)) {
            picked.add(v);
            added = true;
          }
        }
      }
      if (!added) break;
      round++;
    }
    setState(() {
      _playlist = ContinuousPlaylist(picked.isEmpty ? sorted : picked);
      _status = '';
    });
    _playCurrent();
  }

  Future<void> _playCurrent() async {
    final pl = _playlist;
    final video = pl?.current;
    if (pl == null || video == null || _busy) return;
    _busy = true;
    try {
      final url = await YouTubeService.resolveStreamUrl(video.id);
      if (url == null) {
        setState(() => _status = 'Bài này không phát được, chuyển bài sau...');
        pl.skipBroken();
        _busy = false;
        _playCurrent();
        return;
      }
      await _controller?.dispose();
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize();
      await ctrl.play();
      ctrl.addListener(() {
        // Hết bài → tự chuyển bài kế
        if (ctrl.value.position >= ctrl.value.duration &&
            !ctrl.value.isBuffering) {
          _next();
        }
        if (ctrl.value.hasError) {
          _next();
        }
      });
      if (!mounted) {
        await ctrl.dispose();
        _busy = false;
        return;
      }
      setState(() {
        _controller = ctrl;
        _nowTitle = video.title;
        _status = '';
      });
    } catch (_) {
      pl.skipBroken();
    }
    _busy = false;
  }

  Future<void> _next() async {
    final pl = _playlist;
    if (pl == null) return;
    if (!pl.canNext) {
      // Hết playlist → quay về đầu (chạy liên tục)
      pl.index = 0;
    } else {
      pl.next();
    }
    if (mounted) setState(() => _nowTitle = pl.current?.title ?? '');
    await _playCurrent();
  }

  Future<void> _prev() async {
    final pl = _playlist;
    if (pl == null) return;
    pl.prev();
    if (mounted) setState(() => _nowTitle = pl.current?.title ?? '');
    await _playCurrent();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final playing = c?.value.isPlaying ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${widget.category.icon} ${widget.category.name}',
          style: const TextStyle(fontSize: 16, color: Colors.white),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _loadFailed
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi_off_rounded,
                            size: 46, color: Colors.white38),
                        const SizedBox(height: Sp.m),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: Sp.xxl),
                          child: Text(
                            _status,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 15),
                          ),
                        ),
                        const SizedBox(height: Sp.l),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: _loadPlaylist,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    )
                  : _status.isNotEmpty
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(color: _accent),
                            const SizedBox(height: Sp.l),
                            Text(_status,
                                style: const TextStyle(
                                    fontSize: 15, color: Colors.white)),
                          ],
                        )
                      : c != null && c.value.isInitialized
                          ? AspectRatio(
                              aspectRatio: c.value.aspectRatio,
                              child: VideoPlayer(c),
                            )
                          : const CircularProgressIndicator(color: _accent),
            ),
          ),
          // Tên bài đang phát + điều khiển
          Container(
            width: double.infinity,
            color: const Color(0xFF12181F),
            padding: const EdgeInsets.fromLTRB(Sp.l, Sp.m, Sp.l, Sp.l),
            child: Column(
              children: [
                Text(
                  _nowTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white),
                ),
                const SizedBox(height: Sp.m),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CircleBtn(
                        icon: Icons.skip_previous_rounded,
                        label: 'Bài trước',
                        onTap: _prev),
                    const SizedBox(width: Sp.xl),
                    _CircleBtn(
                      icon: playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      label: 'Dừng / Phát',
                      big: true,
                      onTap: () {
                        if (c == null) return;
                        setState(() {
                          c.value.isPlaying ? c.pause() : c.play();
                        });
                      },
                    ),
                    const SizedBox(width: Sp.xl),
                    _CircleBtn(
                        icon: Icons.skip_next_rounded,
                        label: 'Bài sau',
                        onTap: _next),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút tròn trên nền tối của trình phát YouTube.
class _CircleBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool big;

  const _CircleBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = big ? 62.0 : 48.0;
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: big
            ? const Color(0xFFFFC93C)
            : Colors.white.withValues(alpha: 0.10),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: big ? 32 : 24,
              color: big ? Colors.black : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
