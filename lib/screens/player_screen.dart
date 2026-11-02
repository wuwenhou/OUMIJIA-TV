import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models.dart';
import '../services/prefs_service.dart';
import '../services/voice_service.dart';
import '../theme/design_system.dart';
import '../widgets/channel_card.dart';

/// Trình phát TRUYỀN HÌNH toàn màn hình.
/// - Điều khiển TV: ↑↓ = đổi kênh, OK = dừng/phát, Back = thoát
/// - Link hỏng → tự thử link dự phòng → hiện lỗi + nút "Thử lại"
/// - Overlay: logo + tên kênh + trạng thái LIVE, yêu thích, giọng nói.
///
/// Giao diện player luôn tối (media surface), kể cả app đang ở Light Mode.
class PlayerScreen extends StatefulWidget {
  final AppConfig config;
  final Channel channel;

  const PlayerScreen({super.key, required this.config, required this.channel});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late Channel _channel;
  VideoPlayerController? _controller;
  String _status = 'Đang kết nối...';
  bool _controlsVisible = true;
  Timer? _hideTimer;
  int _urlIndex = 0;

  /// màu nhấn cố định của vùng media (đảm bảo tương phản trên nền video)
  static const _accent = Color(0xFFFFC93C);

  bool get _loading =>
      _status.startsWith('Đang kết nối') || _status.startsWith('Đang tải');
  bool get _hasError => _status.contains('lỗi');

  @override
  void initState() {
    super.initState();
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
    _hideTimer?.cancel();
    _controller?.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _play() async {
    setState(() => _status = 'Đang kết nối...');
    await _controller?.dispose();
    _controller = null;

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
      await ctrl.setLooping(true);
      await ctrl.play();
      if (!mounted) {
        await ctrl.dispose();
        return;
      }
      setState(() {
        _controller = ctrl;
        _status = '';
      });
      await PrefsService.recordChannelOpened(_channel.id);
      ctrl.addListener(() {
        if (!mounted) return;
        if (ctrl.value.hasError) {
          // Link hỏng → tự thử link dự phòng
          _tryNextUrl();
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
      // Thử link dự phòng
      _urlIndex++;
      if (_urlIndex < urls.length) {
        _play();
      } else {
        if (mounted) {
          setState(() => _status = 'Kênh này tạm lỗi. Vui lòng chọn kênh khác.');
        }
      }
    }
  }

  Future<void> _tryNextUrl() async {
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

  void _switchChannel(int delta) {
    final channels = widget.config.channels;
    final i = channels.indexWhere((c) => c.id == _channel.id);
    final next = channels[(i + delta + channels.length) % channels.length];
    setState(() {
      _channel = next;
      _urlIndex = 0;
    });
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
      await c.pause();
    } else {
      await c.play();
    }
    _showControls();
  }

  void _showControls() {
    setState(() => _controlsVisible = true);
    _scheduleHideControls();
  }

  Future<void> _openVoice() async {
    _showControls();
    if (!PrefsService.voiceEnabled) return;
    final messenger = ScaffoldMessenger.of(context);
    final voice = VoiceService();
    final ok = await voice.init();
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Không dùng được micro trên máy này.')));
      return;
    }
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _VoiceDialog(config: widget.config, voice: voice),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final favorite = PrefsService.isFavorite(_channel.id);
    final playing = c?.value.isPlaying ?? false;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _showControls,
        child: Focus(
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

              // ================= OVERLAY ĐIỀU KHIỂN =================
              AnimatedOpacity(
                opacity: _controlsVisible ? 1 : 0,
                duration: const Duration(milliseconds: 250),
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
                        // ---------- hàng trên ----------
                        SafeArea(
                          bottom: false,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(Sp.l, Sp.s, Sp.s, 0),
                            child: Row(
                              children: [
                                ChannelLogo(channel: _channel, size: 44),
                                const SizedBox(width: Sp.m),
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
                                    if (PrefsService.voiceEnabled) ...[
                                      const SizedBox(width: Sp.xl + Sp.s),
                                      _ControlButton(
                                        icon: Icons.mic_rounded,
                                        label: 'Giọng nói',
                                        accent: true,
                                        onPressed: _openVoice,
                                      ),
                                    ],
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
                  ),
                ),
              ),
            ],
          ),
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

/// Nút phụ dưới đáy (kênh trước/sau, micro).
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool accent;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.accent = false,
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
                  color: accent
                      ? const Color(0xFFFFC93C)
                      : Colors.white,
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

/// Hộp thoại giọng nói: nghe → hiện kết quả → người dùng xác nhận → thực hiện.
class _VoiceDialog extends StatefulWidget {
  final AppConfig config;
  final VoiceService voice;

  const _VoiceDialog({required this.config, required this.voice});

  @override
  State<_VoiceDialog> createState() => _VoiceDialogState();
}

class _VoiceDialogState extends State<_VoiceDialog> {
  String _heard = '';
  VoiceCommand? _command;
  bool _listening = true;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() {
      _listening = true;
      _heard = '';
      _command = null;
    });
    final text = await widget.voice.listenOnce(onPartial: (t) {
      if (mounted) setState(() => _heard = t);
    });
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      setState(() {
        _listening = false;
        _command = VoiceCommand(type: VoiceCommandType.unknown, rawText: '');
      });
      return;
    }
    setState(() {
      _listening = false;
      _command = VoiceService.parse(text, widget.config);
    });
  }

  @override
  void dispose() {
    widget.voice.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final cmd = _command;
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(Sp.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.accent.withValues(alpha: 0.16),
              ),
              child: Icon(
                _listening ? Icons.mic_rounded : Icons.hearing_rounded,
                size: 32,
                color: c.accent,
              ),
            ),
            const SizedBox(height: Sp.l),
            Text(
              _listening ? 'Xin mời nói...' : 'Bạn vừa nói:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: Sp.s),
            Text(
              _heard.isEmpty ? '...' : _heard,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (cmd != null && !cmd.isUnknown) ...[
              const SizedBox(height: Sp.l),
              Text(
                cmd.confirmation,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: c.accent, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: Sp.xl),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(cmd),
                      child: const Text('Đồng ý'),
                    ),
                  ),
                  const SizedBox(width: Sp.m),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _start,
                      child: const Text('Nói lại'),
                    ),
                  ),
                ],
              ),
            ] else if (!_listening) ...[
              const SizedBox(height: Sp.l),
              Text(
                'Không hiểu lệnh. Thử nói: "Bật VTV3"',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: Sp.xl),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _start,
                      child: const Text('Nói lại'),
                    ),
                  ),
                  const SizedBox(width: Sp.m),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Đóng'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
