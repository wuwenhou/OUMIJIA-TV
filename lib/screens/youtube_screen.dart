import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models.dart';
import '../services/youtube_service.dart';
import '../theme/design_system.dart';

/// Một chủ đề trong bảng tin YouTube (mỗi chủ đề là một từ khóa tìm kiếm).
class _Topic {
  final String label;
  final String query;
  const _Topic(this.label, this.query);
}

const _topics = <_Topic>[
  _Topic('Đề xuất', 'việt nam hôm nay'),
  _Topic('Tin tức', 'tin tức việt nam'),
  _Topic('Âm nhạc', 'nhạc việt nam'),
  _Topic('Phim', 'phim việt nam'),
  _Topic('Hài', 'hài việt nam'),
  _Topic('Thiếu nhi', 'hoạt hình thiếu nhi'),
  _Topic('Thể thao', 'thể thao việt nam'),
  _Topic('Công nghệ', 'công nghệ việt nam'),
  _Topic('Du lịch', 'du lịch việt nam'),
];

/// Tab YOUTUBE — bảng tin kiểu ứng dụng YouTube:
/// tìm kiếm + chủ đề + danh sách video, phát trực tiếp không quảng cáo.
class YouTubeScreen extends StatefulWidget {
  final AppConfig config;

  const YouTubeScreen({super.key, required this.config});

  @override
  State<YouTubeScreen> createState() => _YouTubeScreenState();
}

class _YouTubeScreenState extends State<YouTubeScreen> {
  final _searchCtrl = TextEditingController();
  _Topic _topic = _topics.first;
  List<YouTubeVideo> _videos = const [];
  bool _loading = true;
  String _error = '';
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _request++;
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool force = false}) async {
    final gen = ++_request;
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final videos = await YouTubeService.fetchFeed(_topic.query, force: force);
      if (!mounted || gen != _request) return;
      setState(() {
        _videos = videos;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || gen != _request) return;
      setState(() {
        _loading = false;
        _error = e is YouTubeSourceException
            ? e.message
            : 'Không tải được bảng tin YouTube. Vui lòng thử lại.';
      });
    }
  }

  void _chooseTopic(_Topic topic) {
    FocusScope.of(context).unfocus();
    _searchCtrl.clear();
    setState(() => _topic = topic);
    _load();
  }

  void _search(String raw) {
    final q = raw.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() => _topic = _Topic('Tìm kiếm', q));
    _load();
  }

  Future<void> _openVideo(int index) async {
    await Navigator.of(context).push(MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => YouTubePlayerScreen(
        videos: List<YouTubeVideo>.unmodifiable(_videos),
        initialIndex: index,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Scaffold(
      appBar: AppBar(
        title: const Text('YouTube'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            onPressed: _loading ? null : () => _load(force: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _load(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(Sp.xl, Sp.s, Sp.xl, Sp.xxl + Sp.l),
          children: [
            // ------------------- tìm kiếm -------------------
            TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Tìm video trên YouTube',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  tooltip: 'Tìm',
                  onPressed: () => _search(_searchCtrl.text),
                  icon: const Icon(Icons.arrow_forward_rounded),
                ),
                filled: true,
                fillColor: c.surface,
                contentPadding: const EdgeInsets.symmetric(vertical: Sp.m),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.xl),
                  borderSide: BorderSide(color: c.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(Radii.xl),
                  borderSide: BorderSide(color: c.border),
                ),
              ),
            ),
            const SizedBox(height: Sp.m),

            // ------------------- chủ đề -------------------
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final topic in _topics)
                    Padding(
                      padding: const EdgeInsets.only(right: Sp.s),
                      child: ChoiceChip(
                        label: Text(topic.label),
                        selected: _topic.label == topic.label,
                        onSelected: (_) => _chooseTopic(topic),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: Sp.m),
            if (_loading && _videos.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: Sp.m),
                child: LinearProgressIndicator(minHeight: 2),
              ),
            if (_error.isNotEmpty)
              _ErrorCard(message: _error, onRetry: () => _load(force: true))
            else if (_loading && _videos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: Sp.xxl * 2),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.only(bottom: Sp.m),
                child: Text(
                  '${_videos.length} video · không quảng cáo',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              for (var i = 0; i < _videos.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: Sp.l),
                  child: _VideoCard(
                    video: _videos[i],
                    onTap: () => _openVideo(i),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Thẻ video kiểu bảng tin YouTube: ảnh 16:9, thời lượng, tiêu đề + kênh.
class _VideoCard extends StatelessWidget {
  final YouTubeVideo video;
  final VoidCallback onTap;

  const _VideoCard({required this.video, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final meta = [
      if (video.author.isNotEmpty) video.author,
      if (video.viewsText.isNotEmpty) video.viewsText,
      if (video.publishedText.isNotEmpty) video.publishedText,
    ].join(' · ');

    return Material(
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
                        child: Icon(Icons.smart_display_outlined,
                            size: 34, color: c.textLo),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.55),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.35)),
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 30),
                      ),
                    ),
                    if (video.durationLabel.isNotEmpty)
                      Positioned(
                        right: Sp.s,
                        bottom: Sp.s,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            video.durationLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(Sp.m, Sp.m, Sp.m, Sp.m),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      video.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: c.textHi,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 4),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: Sp.l),
      padding: const EdgeInsets.all(Sp.l),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.m),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 40, color: c.textLo),
          const SizedBox(height: Sp.s),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: Sp.m),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: const Text('Thử lại'),
          ),
        ],
      ),
    );
  }
}

/// Trình phát YouTube toàn màn hình, không quảng cáo.
/// - Tự dừng khi app vào nền / tắt màn hình; chỉ tự phát lại khi quay lại.
/// - Chuyển video trước/sau; lỗi luồng có nút thử lại.
class YouTubePlayerScreen extends StatefulWidget {
  final List<YouTubeVideo> videos;
  final int initialIndex;

  const YouTubePlayerScreen({
    super.key,
    required this.videos,
    this.initialIndex = 0,
  });

  @override
  State<YouTubePlayerScreen> createState() => _YouTubePlayerScreenState();
}

class _YouTubePlayerScreenState extends State<YouTubePlayerScreen>
    with WidgetsBindingObserver {
  static const _accent = Color(0xFFFFC93C);

  late int _index;
  VideoPlayerController? _controller;
  String _status = 'Đang lấy luồng phát...';
  String _error = '';
  bool _manualPause = false;
  bool _autoPaused = false;
  int _generation = 0;
  bool _controlsVisible = true;
  Timer? _hideTimer;

  YouTubeVideo? get _video =>
      widget.videos.isEmpty ? null : widget.videos[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.videos.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.videos.length - 1).toInt();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _load();
  }

  @override
  void dispose() {
    _generation++;
    _hideTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
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

  Future<void> _load() async {
    final video = _video;
    final gen = ++_generation;
    final old = _controller;
    _controller = null;
    if (mounted) {
      setState(() {
        _status = 'Đang lấy luồng phát...';
        _error = '';
        _manualPause = false;
        _autoPaused = false;
      });
    }
    // Dừng và giải phóng video cũ TRƯỚC khi lấy luồng mới, để video trước
    // không tiếp tục phát khi người dùng chuyển bài.
    if (old != null) {
      try {
        await old.pause();
        await old.dispose();
      } catch (_) {}
    }
    if (video == null) {
      if (mounted) setState(() => _status = 'Danh sách video trống.');
      return;
    }

    try {
      final url = await YouTubeService.resolveStreamUrl(video.id);
      if (!mounted || gen != _generation) return;
      if (url == null) {
        throw YouTubeSourceException('Video này không có luồng phát phù hợp.');
      }
      final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));
      await ctrl.initialize();
      if (!mounted || gen != _generation) {
        await ctrl.dispose();
        return;
      }
      ctrl.addListener(() {
        if (!mounted || gen != _generation) return;
        if (ctrl.value.hasError && _error.isEmpty) {
          setState(() => _error = 'Không phát được video này.');
        }
        if (mounted) setState(() {}); // cập nhật nút play/pause
      });
      await ctrl.play();
      if (!mounted || gen != _generation) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _controller = ctrl;
        _status = '';
      });
      _scheduleHideControls();
    } catch (e) {
      if (!mounted || gen != _generation) return;
      setState(() {
        _error = e is YouTubeSourceException
            ? e.message
            : 'Không phát được video này. Vui lòng thử lại.';
      });
    }
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.videos.length) return;
    setState(() => _index = next);
    _load();
  }

  void _togglePlay() {
    final ctrl = _controller;
    if (ctrl == null) return;
    if (ctrl.value.isPlaying) {
      _manualPause = true;
      ctrl.pause();
    } else {
      _manualPause = false;
      _autoPaused = false;
      ctrl.play();
    }
    _showControls();
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _scheduleHideControls();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    final playing = ctrl?.value.isPlaying ?? false;
    final video = _video;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _showControls,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ------------------- video / trạng thái -------------------
            if (ctrl != null && ctrl.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: ctrl.value.aspectRatio,
                  child: VideoPlayer(ctrl),
                ),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_error.isEmpty)
                        const SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            color: _accent,
                            strokeWidth: 3,
                          ),
                        )
                      else
                        const Icon(Icons.wifi_off_rounded,
                            color: Colors.white38, size: 52),
                      const SizedBox(height: 18),
                      Text(
                        _error.isNotEmpty ? _error : _status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_error.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.black,
                          ),
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded, size: 22),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // ------------------- overlay điều khiển -------------------
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 220),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xCC000000),
                        Color(0x14000000),
                        Color(0x22000000),
                        Color(0xE0000000),
                      ],
                      stops: [0.0, 0.3, 0.7, 1.0],
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(Sp.s, Sp.s, Sp.l, 0),
                          child: Row(
                            children: [
                              IconButton(
                                tooltip: 'Đóng',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded,
                                    color: Colors.white),
                              ),
                              const SizedBox(width: Sp.xs),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      video?.title ?? 'YouTube',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                    if ((video?.author ?? '').isNotEmpty)
                                      Text(
                                        video!.author,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white
                                              .withValues(alpha: 0.65),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: Sp.m),
                              Text(
                                widget.videos.isEmpty
                                    ? ''
                                    : '${_index + 1}/${widget.videos.length}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: Sp.m),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _PlayerButton(
                                icon: Icons.skip_previous_rounded,
                                label: 'Trước',
                                onPressed:
                                    _index > 0 ? () => _go(-1) : null,
                              ),
                              const SizedBox(width: Sp.xxl),
                              Material(
                                color: _accent,
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: ctrl == null ? null : _togglePlay,
                                  child: SizedBox(
                                    width: 64,
                                    height: 64,
                                    child: Icon(
                                      playing
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      size: 34,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: Sp.xxl),
                              _PlayerButton(
                                icon: Icons.skip_next_rounded,
                                label: 'Sau',
                                onPressed: _index < widget.videos.length - 1
                                    ? () => _go(1)
                                    : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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

class _PlayerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _PlayerButton({
    required this.icon,
    required this.label,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.white.withValues(alpha: 0.10),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                width: 52,
                height: 52,
                child: Icon(
                  icon,
                  size: 26,
                  color: enabled ? Colors.white : Colors.white24,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: enabled ? 0.65 : 0.3),
            ),
          ),
        ],
      ),
    );
  }
}
