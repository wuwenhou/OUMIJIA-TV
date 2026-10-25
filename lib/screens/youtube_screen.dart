import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

import '../models.dart';
import '../services/youtube_service.dart';
import '../ui.dart';

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
    final cats = widget.config.youtubeCategories;
    if (cats.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Chưa có danh mục YouTube.\n'
            'Thêm kênh bằng cách sửa file config/channels.json trên GitHub.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, color: Ui.textSecondary),
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: cats.length,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (context, i) {
        final cat = cats[i];
        return Focus(
          child: Builder(builder: (context) {
            final focused = Focus.of(context).hasFocus;
            return Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: focused ? Ui.focusBorder : Colors.transparent,
                    width: 4),
              ),
              child: Card(
                color: Ui.surface,
                margin: EdgeInsets.zero,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 18),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      fullscreenDialog: true,
                      builder: (_) => _CategoryPlayerScreen(category: cat),
                    ));
                  },
                  leading: Text(cat.icon,
                      style: const TextStyle(fontSize: 44)),
                  title: Text(cat.name,
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Ui.textPrimary)),
                  subtitle: Text(
                    '${cat.channels.length} kênh đã duyệt',
                    style: const TextStyle(
                        fontSize: 18, color: Ui.textSecondary),
                  ),
                  trailing: const Icon(Icons.play_circle_fill,
                      size: 48, color: Ui.accent),
                ),
              ),
            );
          }),
        );
      },
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
      ..sort((a, b) => b.uploadDate?.compareTo(a.uploadDate ?? DateTime(2000)) ?? 0);
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          '${widget.category.icon} ${widget.category.name}',
          style: const TextStyle(fontSize: 24, color: Colors.white),
        ),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _status.isNotEmpty
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Ui.accent),
                        const SizedBox(height: 16),
                        Text(_status,
                            style: const TextStyle(
                                fontSize: 22, color: Colors.white)),
                      ],
                    )
                  : c != null && c.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: c.value.aspectRatio,
                          child: VideoPlayer(c),
                        )
                      : const CircularProgressIndicator(color: Ui.accent),
            ),
          ),
          // Tên bài đang phát + nút điều khiển to
          Container(
            color: Ui.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                Text(
                  _nowTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Ui.textPrimary),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _BigBtn(
                        icon: Icons.skip_previous,
                        label: 'Bài trước',
                        onTap: _prev),
                    const SizedBox(width: 20),
                    _BigBtn(
                      icon: (c?.value.isPlaying ?? false)
                          ? Icons.pause
                          : Icons.play_arrow,
                      label: 'Dừng / Phát',
                      onTap: () {
                        if (c == null) return;
                        setState(() {
                          c.value.isPlaying ? c.pause() : c.play();
                        });
                      },
                    ),
                    const SizedBox(width: 20),
                    _BigBtn(icon: Icons.skip_next, label: 'Bài sau', onTap: _next),
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

class _BigBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BigBtn({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.black45,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: Ui.minTouchTarget,
              height: Ui.minTouchTarget,
              child: Icon(icon, size: 38, color: Ui.accent),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 16, color: Ui.textSecondary)),
      ],
    );
  }
}
