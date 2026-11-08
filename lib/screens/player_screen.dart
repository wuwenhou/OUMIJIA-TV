import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models.dart';
import '../services/prefs_service.dart';
import '../theme/design_system.dart';
import '../widgets/channel_card.dart';

/// Trình phát TRUYỀN HÌNH toàn màn hình.
/// - Điều khiển TV: ↑↓ = đổi kênh, OK = dừng/phát, Back = thoát
/// - Link hỏng → tự thử link dự phòng → hiện lỗi + nút "Thử lại"
/// - Rời app / tắt màn hình → dừng phát; quay lại mới tự phát tiếp
/// - Đổi kênh → dừng và giải phóng video cũ trước khi kết nối kênh mới
/// - Overlay: tên kênh + trạng thái LIVE, yêu thích.
///
/// Giao diện player luôn tối (media surface), kể cả app đang ở Light Mode.
class PlayerScreen extends StatefulWidget {
  final AppConfig config;
  final Channel channel;

  const PlayerScreen({super.key, required this.config, required this.channel});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen>
    with WidgetsBindingObserver {
  late Channel _channel;
  VideoPlayerController? _controller;
  String _status = 'Đang kết nối...';
  bool _controlsVisible = true;
  Timer? _hideTimer;
  int _urlIndex = 0;

  /// Tăng mỗi lần đổi kênh/nguồn. Callback của lần tải cũ bị bỏ qua.
  int _generation = 0;

  /// Người dùng chủ động dừng → không tự phát lại khi app quay lại.
  bool _manualPause = false;

  /// App đã tự dừng khi vào nền → được phép tự phát lại.
  bool _autoPaused = false;

  /// màu nhấn cố định của vùng media (đảm bảo tương phản trên nền video)
  static const _accent = Color(0xFFFFC93C);

  bool get _loading =>
      _status.startsWith('Đang kết nối') || _status.startsWith('Đang tải');
  bool get _hasError => _status.contains('lỗi');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _channel = widget.channel;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
      DeviceOrientation.portraitUp,
    ]);
    _play();
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
      // Chỉ tự phát lại nếu lần dừng trước do app vào nền, không phải do
      // người dùng bấm dừng.
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

  Future<void> _play() async {
    final gen = ++_generation;
    final old = _controller;
    _controller = null;
    if (mounted) {
      setState(() {
        _status = 'Đang kết nối...';
        _manualPause = false;
        _autoPaused = false;
      });
    }

    // Dừng + giải phóng video cũ trước khi lấy nguồn mới. Đây là điểm quan
    // trọng để kênh trước không tiếp tục phát sau khi đổi kênh.
    if (old != null) {
      try {
        await old.pause();
        await old.dispose();
      } catch (_) {}
    }
    if (!mounted || gen != _generation) return;

    final urls = _channel.allUrls;
    if (_urlIndex >= urls.length) {
      setState(() => _status = 'Kênh này tạm lỗi. Vui lòng chọn kênh khác.');
      return;
    }

    final url = urls[_urlIndex];
    final ctrl = VideoPlayerController.networkUrl(
      Uri.parse(url),
      httpHeaders: _channel.headers,
    );

    try {
      await ctrl.initialize();
      if (!mounted || gen != _generation) {
        await ctrl.dispose();
        return;
      }
      await ctrl.setLooping(true);
      await ctrl.play();
      if (!mounted || gen != _generation) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _controller = ctrl;
        _status = '';
      });
      await PrefsService.recordChannelOpened(_channel.id);
      if (!mounted || gen != _generation) return;
      ctrl.addListener(() {
        if (!mounted || gen != _generation) return;
        if (ctrl.value.hasError) {
          // Link hỏng → tự thử link dự phòng
          _tryNextUrl(gen);
        } else if (ctrl.value.isBuffering && _status != 'Đang kết nối...') {
          setState(() => _status = 'Đang tải...');
        } else if (!ctrl.value.isBuffering && _status == 'Đang tải...') {
          setState(() => _status = '');
        }
        if (mounted) setState(() {}); // cập nhật nút pause/play
      });
      _scheduleHideControls();
    } catch (_) {
      await ctrl.dispose();
      if (!mounted || gen != _generation) return;
      // Thử link dự phòng
      _urlIndex++;
      if (_urlIndex < urls.length) {
        _play();
      } else {
        setState(() => _status = 'Kênh này tạm lỗi. Vui lòng chọn kênh khác.');
      }
    }
  }

  Future<void> _tryNextUrl(int gen) async {
    if (!mounted || gen != _generation) return;
    if (_urlIndex + 1 < _channel.allUrls.length) {
      _urlIndex++;
      await _play();
    }
  }

  /// Người dùng bấm "Thử lại": quay về nguồn chính rồi thử toàn bộ fallback.
  Future<void> _retry() async {
    _urlIndex = 0;
    await _play();
  }

  List<Channel> get _displayChannels {
    final favorites = <Channel>[];
    final others = <Channel>[];
    for (final channel in widget.config.channels) {
      if (PrefsService.isFavorite(channel.id)) {
        favorites.add(channel);
      } else {
        others.add(channel);
      }
    }
    return [...favorites, ...others];
  }

  void _switchChannel(int delta) {
    final channels = _displayChannels;
    if (channels.isEmpty) return;
    final i = channels.indexWhere((c) => c.id == _channel.id);
    final current = i < 0 ? 0 : i;
    final next = channels[(current + delta + channels.length) % channels.length];

    // Dừng ngay video cũ và xoá khỏi giao diện trước khi đổi kênh.
    final old = _controller;
    _controller = null;
    _hideTimer?.cancel();
    setState(() {
      _channel = next;
      _urlIndex = 0;
      _status = 'Đang kết nối...';
      _controlsVisible = true;
      _manualPause = false;
      _autoPaused = false;
    });
    if (old != null) {
      unawaited(old.pause());
      unawaited(old.dispose());
    }
    _play();
  }

  void _scheduleHideControls() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _controlsVisible = false);
    });
  }

  void _togglePlay() async {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      _manualPause = true;
      await c.pause();
    } else {
      _manualPause = false;
      _autoPaused = false;
      await c.play();
    }
    _showControls();
  }

  void _showControls() {
    if (!mounted) return;
    setState(() => _controlsVisible = true);
    _scheduleHideControls();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final favorite = PrefsService.isFavorite(_channel.id);
    final playing = c?.value.isPlaying ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ================= VIDEO / TRẠNG THÁI =================
            if (c != null && c.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              )
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_loading)
                        const SizedBox(
                          width: 44,
                          height: 44,
                          child: CircularProgressIndicator(
                            color: _accent,
                            strokeWidth: 3,
                          ),
                        )
                      else if (_hasError)
                        const Icon(Icons.wifi_off_rounded,
                            color: Colors.white38, size: 52),
                      const SizedBox(height: 18),
                      Text(
                        _status.isEmpty ? _channel.name : _status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          height: 1.4,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_hasError) ...[
                        const SizedBox(height: 22),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 26, vertical: 14),
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 22),
                          label: const Text('Thử lại'),
                          onPressed: _retry,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

            // Bất kỳ vùng nào của màn hình (kể cả phần đen ngoài video)
            // đều bật/tắt thanh điều khiển khi chạm.
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (_controlsVisible) {
                    _hideTimer?.cancel();
                    setState(() => _controlsVisible = false);
                  } else {
                    _showControls();
                  }
                },
              ),
            ),

            // ================= OVERLAY ĐIỀU KHIỂN =================
            AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 250),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: Stack(
                  children: [
                    // Lớp gradient chỉ để che nền overlay, không nhận chạm.
                    IgnorePointer(
                      ignoring: true,
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
                      ),
                    ),
                    Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // ---------- hàng trên ----------
                      SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(Sp.l, Sp.s, Sp.s, 0),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _channel.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    _PlaybackChip(
                                      status: _status,
                                      error: _hasError,
                                      loading: _loading,
                                    ),
                                  ],
                                ),
                              ),
                              _GlassButton(
                                icon: favorite
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                iconColor: favorite ? _accent : Colors.white,
                                tooltip: 'Yêu thích',
                                onPressed: () async {
                                  await PrefsService.toggleFavorite(_channel.id);
                                  if (mounted) setState(() {});
                                  _showControls();
                                },
                              ),
                              const SizedBox(width: Sp.s),
                              _GlassButton(
                                icon: Icons.close_rounded,
                                tooltip: 'Thoát',
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              const SizedBox(width: Sp.s),
                            ],
                          ),
                        ),
                      ),

                      // ---------- hàng dưới ----------
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: Sp.m),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  _ControlButton(
                                    icon: Icons.skip_previous_rounded,
                                    label: 'Kênh trước',
                                    onPressed: () => _switchChannel(-1),
                                  ),
                                  const SizedBox(width: Sp.xl + Sp.s),
                                  _PlayPauseButton(
                                    playing: playing,
                                    onPressed: _togglePlay,
                                  ),
                                  const SizedBox(width: Sp.xl + Sp.s),
                                  _ControlButton(
                                    icon: Icons.skip_next_rounded,
                                    label: 'Kênh sau',
                                    onPressed: () => _switchChannel(1),
                                  ),
                                ],
                              ),
                              const SizedBox(height: Sp.s),
                              Text(
                                '↑↓ đổi kênh · OK dừng/phát · Back thoát',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.white.withValues(alpha: 0.45),
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    _showControls();
    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowRight ||
        key == LogicalKeyboardKey.channelUp) {
      _switchChannel(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.channelDown) {
      _switchChannel(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.mediaPlayPause ||
        key == LogicalKeyboardKey.space) {
      _togglePlay();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

/// Chip trạng thái phát trên overlay: LIVE / đang tải / mất kết nối.
class _PlaybackChip extends StatelessWidget {
  final String status;
  final bool error;
  final bool loading;

  const _PlaybackChip({
    required this.status,
    required this.error,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color color;
    if (error) {
      label = 'MẤT KẾT NỐI';
      color = const Color(0xFFFF6B6B);
    } else if (loading) {
      label = status.toUpperCase();
      color = const Color(0xFFFFC93C);
    } else {
      label = 'LIVE';
      color = const Color(0xFF39D98A);
    }
    return StatusChip(text: label, color: color, pulsing: !error && !loading);
  }
}

/// Nút tròn kiểu "glass" trên video (48dp).
class _GlassButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final Color iconColor;

  const _GlassButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.10),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(icon, size: 24, color: iconColor),
          ),
        ),
      ),
    );
  }
}

/// Nút phụ dưới đáy (kênh trước/sau).
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
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
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nút phát/dừng chính — nổi bật bằng accent, 64dp.
class _PlayPauseButton extends StatelessWidget {
  final bool playing;
  final VoidCallback onPressed;

  const _PlayPauseButton({required this.playing, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFC93C),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: 64,
          height: 64,
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: 34,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
