import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models.dart';
import '../theme/design_system.dart';
import '../widgets/channel_card.dart';

/// Tab PHIM — poster theo nhóm, mở trình phát toàn màn hình.
/// Dữ liệu lấy từ config (GitHub), hiện đang trống → trạng thái rỗng lịch sự.
class MoviesScreen extends StatelessWidget {
  final AppConfig config;

  const MoviesScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final movies = config.movies;

    // Nhóm phim theo "group" (giữ thứ tự trong config).
    final groups = <String, List<MovieItem>>{};
    for (final m in movies) {
      groups.putIfAbsent(m.group, () => []).add(m);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Phim')),
      body: movies.isEmpty
          ? const _EmptyMovies()
          : ListView(
              padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.s, Sp.xl, Sp.xxl + Sp.l),
              children: [
                for (final entry in groups.entries) ...[
                  SectionHeader(title: entry.key),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 210,
                      mainAxisSpacing: Sp.m,
                      crossAxisSpacing: Sp.m,
                      childAspectRatio: 0.62,
                    ),
                    itemCount: entry.value.length,
                    itemBuilder: (context, i) =>
                        _MovieCard(movie: entry.value[i]),
                  ),
                ],
              ],
            ),
    );
  }
}

class _EmptyMovies extends StatelessWidget {
  const _EmptyMovies();

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.movie_outlined, size: 52, color: c.textLo),
            const SizedBox(height: Sp.m),
            Text('Chưa có phim trong danh mục',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Sp.xs),
            Text(
              'Chủ ứng dụng có thể thêm phim hợp lệ vào mục "movies" '
              'trong config/channels.json — app sẽ tự cập nhật, không cần phát hành bản mới.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _MovieCard extends StatelessWidget {
  final MovieItem movie;

  const _MovieCard({required this.movie});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Material(
      color: c.surface,
      borderRadius: BorderRadius.circular(Radii.m),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => _MoviePlayerScreen(movie: movie),
          ));
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.m),
            border: Border.all(color: c.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (movie.poster.isEmpty)
                      Container(
                        color: c.surfaceAlt,
                        child: Icon(Icons.movie_outlined,
                            size: 34, color: c.textLo),
                      )
                    else
                      CachedNetworkImage(
                        imageUrl: movie.poster,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: c.surfaceAlt),
                        errorWidget: (_, __, ___) => Container(
                          color: c.surfaceAlt,
                          child: Icon(Icons.broken_image_outlined,
                              size: 30, color: c.textLo),
                        ),
                      ),
                    Positioned(
                      right: Sp.s,
                      bottom: Sp.s,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.55),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25)),
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, Sp.s, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(
                              color: c.textHi, fontWeight: FontWeight.w600),
                    ),
                    if (movie.note.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        movie.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Trình phát phim đơn giản — nền đen, điều khiển nổi, có thử lại khi lỗi.
class _MoviePlayerScreen extends StatefulWidget {
  final MovieItem movie;

  const _MoviePlayerScreen({required this.movie});

  @override
  State<_MoviePlayerScreen> createState() => _MoviePlayerScreenState();
}

class _MoviePlayerScreenState extends State<_MoviePlayerScreen> {
  VideoPlayerController? _controller;
  String _error = '';

  static const _accent = Color(0xFFFFC93C);

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _error = '');
    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.movie.url),
        httpHeaders: widget.movie.headers,
      );
      await ctrl.initialize();
      await ctrl.play();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() => _controller = ctrl);
      ctrl.addListener(() {
        if (mounted && ctrl.value.hasError) {
          setState(() => _error = 'Không phát được phim này.');
        }
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Không phát được phim này.');
    }
  }

  Future<void> _retry() async {
    await _controller?.dispose();
    _controller = null;
    await _init();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final playing = c?.value.isPlaying ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            // video / trạng thái
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                final ctrl = _controller;
                if (ctrl == null || !ctrl.value.isInitialized) return;
                setState(() {
                  ctrl.value.isPlaying ? ctrl.pause() : ctrl.play();
                });
              },
              child: Center(
              child: _error.isNotEmpty
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 46, color: Colors.white38),
                        const SizedBox(height: Sp.m),
                        Text(_error,
                            style: const TextStyle(
                                fontSize: 16, color: Colors.white)),
                        const SizedBox(height: Sp.l),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: _retry,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    )
                  : c == null || !c.value.isInitialized
                      ? const CircularProgressIndicator(color: _accent)
                      : AspectRatio(
                          aspectRatio: c.value.aspectRatio,
                          child: VideoPlayer(c),
                        ),
            ),
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(Sp.s, Sp.s, Sp.l, Sp.xl),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xB3000000), Colors.transparent],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded,
                          color: Colors.white),
                    ),
                    const SizedBox(width: Sp.xs),
                    Expanded(
                      child: Text(
                        widget.movie.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // nút phát/dừng lớn ở giữa
            if (c != null && c.value.isInitialized && !playing)
              Center(
                child: Material(
                  color: Colors.black.withValues(alpha: 0.45),
                  shape: const CircleBorder(),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        playing ? c.pause() : c.play();
                      });
                    },
                    child: SizedBox(
                      width: 68,
                      height: 68,
                      child: Icon(
                        playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        size: 38,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
