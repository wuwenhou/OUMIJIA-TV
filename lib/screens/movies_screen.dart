import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../models.dart';
import '../services/youtube_service.dart';
import '../theme/design_system.dart';
import '../widgets/channel_card.dart';
import 'youtube_screen.dart';

/// Tab PHIM — hai phần:
/// 1. Nguồn phim động từ kênh YouTube chính thức (RSS công khai) — kênh có
///    phim thuyết minh/lồng tiếng cập nhật liên tục, không cần phát hành app.
/// 2. Danh mục "movies" thủ công trong config (nếu chủ app khai báo).
class MoviesScreen extends StatefulWidget {
  final AppConfig config;

  const MoviesScreen({super.key, required this.config});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen> {
  final Map<String, List<YouTubeVideo>> _feeds = {};
  final Map<String, String> _errors = {};
  int _generation = 0;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant MoviesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.config, widget.config)) {
      _feeds.clear();
      _errors.clear();
      _load(force: true);
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    final sources = widget.config.movieSources;
    if (sources.isEmpty) return;
    final gen = ++_generation;
    if (force && mounted) {
      setState(() {
        _refreshing = true;
        _errors.clear();
      });
    }

    await Future.wait(sources.map((source) async {
      try {
        final videos = await YouTubeService.fetchChannelUploads(
          source.channelId,
          force: force,
        );
        if (!mounted || gen != _generation) return;
        setState(() {
          _feeds[source.id] = videos;
          _errors.remove(source.id);
        });
      } catch (e) {
        if (!mounted || gen != _generation) return;
        setState(() {
          _errors[source.id] =
              e is YouTubeSourceException ? e.message : 'Không tải được nguồn phim.';
        });
      }
    }));

    if (!mounted || gen != _generation) return;
    if (_refreshing) setState(() => _refreshing = false);
  }

  Future<void> _retry(MovieSource source) async {
    final gen = ++_generation;
    setState(() {
      _errors.remove(source.id);
      _feeds.remove(source.id);
    });
    try {
      final videos = await YouTubeService.fetchChannelUploads(
        source.channelId,
        force: true,
      );
      if (!mounted || gen != _generation) return;
      setState(() => _feeds[source.id] = videos);
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _errors[source.id] =
            e is YouTubeSourceException ? e.message : 'Không tải được nguồn phim.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sources = widget.config.movieSources;
    final movies = widget.config.movies;

    if (sources.isEmpty && movies.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Phim')),
        body: const _EmptyMovies(),
      );
    }

    // Nhóm phim thủ công theo "group" (giữ thứ tự trong config).
    final groups = <String, List<MovieItem>>{};
    for (final m in movies) {
      groups.putIfAbsent(m.group, () => []).add(m);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Phim'),
        actions: [
          if (_refreshing)
            const Padding(
              padding: EdgeInsets.only(right: Sp.l),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.fromLTRB(Sp.xl, Sp.s, Sp.xl, Sp.xxl + Sp.l),
          children: [
            if (sources.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.s),
                child: Text(
                  'Phim thuyết minh/lồng tiếng từ kênh chính thức, '
                  'tự cập nhật khi kênh đăng tập mới. Kéo xuống để làm mới.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            for (final source in sources) ...[
              SectionHeader(title: source.name),
              if (source.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.m),
                  child: Text(
                    source.note,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              _SourceRow(
                source: source,
                videos: _feeds[source.id],
                error: _errors[source.id],
                onRetry: () => _retry(source),
              ),
            ],
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
      ),
    );
  }
}

/// Một hàng ngang video mới nhất của một kênh phim.
class _SourceRow extends StatelessWidget {
  final MovieSource source;
  final List<YouTubeVideo>? videos;
  final String? error;
  final VoidCallback onRetry;

  const _SourceRow({
    required this.source,
    required this.videos,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    if (error != null) {
      return Container(
        margin: const EdgeInsets.only(bottom: Sp.l),
        padding: const EdgeInsets.all(Sp.l),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(Radii.m),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: c.textLo),
            const SizedBox(width: Sp.m),
            Expanded(
              child: Text(error!, style: Theme.of(context).textTheme.bodySmall),
            ),
            TextButton(onPressed: onRetry, child: const Text('Thử lại')),
          ],
        ),
      );
    }

    final list = videos;
    if (list == null) {
      return const SizedBox(
        height: 120,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (list.isEmpty) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Sp.l),
        child: Text('Kênh chưa có video công khai.',
            style: Theme.of(context).textTheme.bodySmall),
      );
    }

    return SizedBox(
      height: 232,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(bottom: Sp.s),
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: Sp.m),
        itemBuilder: (context, i) => _SourceVideoCard(
          video: list[i],
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => YouTubePlayerScreen(
                videos: list,
                initialIndex: i,
              ),
            ));
          },
        ),
      ),
    );
  }
}

/// Thẻ video ngang cho nguồn phim động.
class _SourceVideoCard extends StatelessWidget {
  final YouTubeVideo video;
  final VoidCallback onTap;

  const _SourceVideoCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final meta = [
      if (video.publishedText.isNotEmpty) video.publishedText,
      if (video.viewsText.isNotEmpty) video.viewsText,
    ].join(' · ');

    return SizedBox(
      width: 212,
      child: Material(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.m),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(Radii.m),
              border: Border.all(color: c.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: video.thumbnail,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: c.surfaceAlt),
                        errorWidget: (_, __, ___) => Container(
                          color: c.surfaceAlt,
                          child: Icon(Icons.movie_outlined,
                              size: 28, color: c.textLo),
                        ),
                      ),
                      Positioned(
                        right: Sp.s,
                        bottom: Sp.s,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black.withValues(alpha: 0.55),
                            border: Border.all(
                                color: Colors.white.withValues(alpha: 0.25)),
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 19),
                        ),
                      ),
                      if (video.durationLabel.isNotEmpty)
                        Positioned(
                          left: Sp.s,
                          bottom: Sp.s,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              video.durationLabel,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(10, Sp.s, 10, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            video.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: c.textHi,
                                    fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            meta,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
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
            Text('Chưa có nguồn phim',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: Sp.xs),
            Text(
              'Chủ ứng dụng có thể thêm kênh phim chính thức vào mục '
              '"movieSources" trong config/channels.json — app sẽ tự cập nhật, '
              'không cần phát hành bản mới.',
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
            builder: (_) => MoviePlayerScreen(movie: movie),
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

/// Trình phát phim — nền đen, điều khiển nổi, có thử lại khi lỗi.
/// Tự dừng khi app vào nền; chỉ tự phát lại nếu trước đó không bị người dùng
/// bấm dừng.
class MoviePlayerScreen extends StatefulWidget {
  final MovieItem movie;

  const MoviePlayerScreen({super.key, required this.movie});

  @override
  State<MoviePlayerScreen> createState() => _MoviePlayerScreenState();
}

class _MoviePlayerScreenState extends State<MoviePlayerScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  String _error = '';
  int _generation = 0;
  bool _manualPause = false;
  bool _autoPaused = false;

  static const _accent = Color(0xFFFFC93C);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final ctrl = _controller;
    if (state == AppLifecycleState.resumed) {
      if (_autoPaused && !_manualPause && ctrl != null) {
        ctrl.play();
      }
      _autoPaused = false;
    } else if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      if (ctrl != null && ctrl.value.isPlaying) {
        _autoPaused = true;
        ctrl.pause();
      }
    }
  }

  Future<void> _init() async {
    final gen = ++_generation;
    final old = _controller;
    _controller = null;
    if (mounted) {
      setState(() {
        _error = '';
        _manualPause = false;
        _autoPaused = false;
      });
    }
    if (old != null) {
      try {
        await old.pause();
        await old.dispose();
      } catch (_) {}
    }
    if (!mounted || gen != _generation) return;

    try {
      final ctrl = VideoPlayerController.networkUrl(
        Uri.parse(widget.movie.url),
        httpHeaders: widget.movie.headers,
      );
      await ctrl.initialize();
      if (!mounted || gen != _generation) {
        await ctrl.dispose();
        return;
      }
      ctrl.addListener(() {
        if (!mounted || gen != _generation) return;
        if (ctrl.value.hasError) {
          setState(() => _error = 'Không phát được phim này.');
        } else if (mounted) {
          setState(() {});
        }
      });
      await ctrl.play();
      if (!mounted || gen != _generation) {
        await ctrl.dispose();
        return;
      }
      setState(() => _controller = ctrl);
    } catch (_) {
      if (mounted && gen == _generation) {
        setState(() => _error = 'Không phát được phim này.');
      }
    }
  }

  Future<void> _retry() async {
    await _init();
  }

  void _togglePlay() {
    final ctrl = _controller;
    if (ctrl == null || !ctrl.value.isInitialized) return;
    if (ctrl.value.isPlaying) {
      _manualPause = true;
      ctrl.pause();
    } else {
      _manualPause = false;
      _autoPaused = false;
      ctrl.play();
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
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
              onTap: _togglePlay,
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
                    onTap: _togglePlay,
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
