import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models.dart';
import '../ui.dart';

/// Tab PHIM — nguồn ngoài, poster to, lưới 2 cột.
/// Chạm poster → mở trình phát đơn giản (HLS/mp4).
class MoviesScreen extends StatelessWidget {
  final AppConfig config;

  const MoviesScreen({super.key, required this.config});

  @override
  Widget build(BuildContext context) {
    final movies = config.movies;

    if (movies.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Chưa có phim trong danh mục.\n'
            'Thêm phim bằng cách sửa file config/channels.json trên GitHub.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, color: Ui.textSecondary),
          ),
        ),
      );
    }

    // Nhóm phim theo "group" để hiện tiêu đề mục to rõ
    final groups = <String, List<MovieItem>>{};
    for (final m in movies) {
      groups.putIfAbsent(m.group, () => []).add(m);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: groups.length,
      itemBuilder: (context, gi) {
        final group = groups.keys.elementAt(gi);
        final items = groups[group]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(group,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Ui.textPrimary)),
            ),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 220,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 0.68,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) => _MovieCard(movie: items[i]),
            ),
          ],
        );
      },
    );
  }
}

class _MovieCard extends StatelessWidget {
  final MovieItem movie;

  const _MovieCard({required this.movie});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _MoviePlayerScreen(movie: movie),
        ));
      },
      child: Card(
        color: Ui.surface,
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: movie.poster.isEmpty
                  ? const Center(
                      child: Icon(Icons.movie, size: 48, color: Ui.textSecondary))
                  : CachedNetworkImage(
                      imageUrl: movie.poster,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const Center(
                          child: CircularProgressIndicator(color: Ui.accent)),
                      errorWidget: (_, __, ___) => const Center(
                          child: Icon(Icons.broken_image,
                              size: 48, color: Ui.textSecondary)),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                movie.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Ui.textPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Trình phát phim đơn giản — toàn màn hình, nút to.
class _MoviePlayerScreen extends StatefulWidget {
  final MovieItem movie;

  const _MoviePlayerScreen({required this.movie});

  @override
  State<_MoviePlayerScreen> createState() => _MoviePlayerScreenState();
}

class _MoviePlayerScreenState extends State<_MoviePlayerScreen> {
  VideoPlayerController? _controller;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ctrl =
          VideoPlayerController.networkUrl(Uri.parse(widget.movie.url));
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

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(widget.movie.title,
            style: const TextStyle(fontSize: 24, color: Colors.white)),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: Center(
        child: _error.isNotEmpty
            ? Text(_error,
                style: const TextStyle(fontSize: 24, color: Colors.white))
            : c == null || !c.value.isInitialized
                ? const CircularProgressIndicator(color: Ui.accent)
                : AspectRatio(
                    aspectRatio: c.value.aspectRatio,
                    child: VideoPlayer(c),
                  ),
      ),
      floatingActionButton: (c != null && c.value.isInitialized)
          ? FloatingActionButton.large(
              backgroundColor: Ui.accent,
              onPressed: () {
                setState(() {
                  c.value.isPlaying ? c.pause() : c.play();
                });
              },
              child: Icon(
                c.value.isPlaying ? Icons.pause : Icons.play_arrow,
                size: 40,
                color: Colors.black,
              ),
            )
          : null,
    );
  }
}
