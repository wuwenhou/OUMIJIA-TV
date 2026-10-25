import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import '../models.dart';
import '../services/prefs_service.dart';
import '../services/voice_service.dart';
import '../ui.dart';

/// Màn hình phát TRUYỀN HÌNH toàn màn hình.
/// - Nút to: đổi kênh ↑↓, tạm dừng, micro, yêu thích
/// - Điều khiển TV: ↑↓ = đổi kênh, OK = tạm dừng/phát, Back = thoát
/// - Link hỏng → tự thử fallback → báo lỗi chữ to
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
    final ctrl = VideoPlayerController.networkUrl(Uri.parse(url));

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
      await PrefsService.setLastChannel(_channel.id);
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
        if (mounted) setState(() => _status = 'Kênh này tạm lỗi. Vui lòng chọn kênh khác.');
      }
    }
  }

  Future<void> _tryNextUrl() async {
    if (_urlIndex + 1 < _channel.allUrls.length) {
      _urlIndex++;
      await _play();
    }
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
    final dialogContext = context;
    final voice = VoiceService();
    final ok = await voice.init();
    if (!ok) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Không dùng được micro trên máy này.',
              style: TextStyle(fontSize: 20))));
      return;
    }
    if (!mounted) return;
    showDialog(
      context: dialogContext,
      barrierDismissible: true,
      builder: (_) => _VoiceDialog(config: widget.config, voice: voice),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final favorite = PrefsService.isFavorite(_channel.id);

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
              // VIDEO
              if (c != null && c.value.isInitialized)
                Center(
                  child: AspectRatio(
                    aspectRatio: c.value.aspectRatio,
                    child: VideoPlayer(c),
                  ),
                )
              else
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_status.startsWith('Đang kết nối') ||
                          _status.startsWith('Đang tải'))
                        const CircularProgressIndicator(color: Ui.accent),
                      const SizedBox(height: 16),
                      Text(
                        _status.isEmpty ? _channel.name : _status,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 28, color: Ui.textPrimary),
                      ),
                    ],
                  ),
                ),

              // CONTROLS
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
                        colors: [Colors.black54, Colors.transparent, Colors.black54],
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Hàng trên: tên kênh + yêu thích + đóng
                        SafeArea(
                          child: Row(
                            children: [
                              const SizedBox(width: 16),
                              Text(
                                _channel.name,
                                style: const TextStyle(
                                  fontSize: 34,
                                  fontWeight: FontWeight.bold,
                                  color: Ui.textPrimary,
                                ),
                              ),
                              const Spacer(),
                              _BigIconButton(
                                icon: favorite
                                    ? Icons.star
                                    : Icons.star_border,
                                label: 'Yêu thích',
                                color: favorite ? Ui.accent : Colors.white,
                                onPressed: () async {
                                  await PrefsService.toggleFavorite(_channel.id);
                                  if (mounted) setState(() {});
                                  _showControls();
                                },
                              ),
                              _BigIconButton(
                                icon: Icons.close,
                                label: 'Thoát',
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                              const SizedBox(width: 8),
                            ],
                          ),
                        ),
                        // Hàng dưới: kênh trước | pause | kênh sau | micro
                        SafeArea(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _BigIconButton(
                                icon: Icons.skip_previous,
                                label: 'Kênh trước',
                                onPressed: () => _switchChannel(-1),
                              ),
                              const SizedBox(width: 24),
                              _BigIconButton(
                                icon: (c?.value.isPlaying ?? false)
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                label: 'Dừng / Phát',
                                onPressed: _togglePlay,
                              ),
                              const SizedBox(width: 24),
                              _BigIconButton(
                                icon: Icons.skip_next,
                                label: 'Kênh sau',
                                onPressed: () => _switchChannel(1),
                              ),
                              if (PrefsService.voiceEnabled) ...[
                                const SizedBox(width: 24),
                                _BigIconButton(
                                  icon: Icons.mic,
                                  label: 'Nói lệnh',
                                  color: Ui.accent,
                                  onPressed: _openVoice,
                                ),
                              ],
                            ],
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

/// Nút tròn to có nhãn — chuẩn chạm cho người già (>= 64dp).
class _BigIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color color;

  const _BigIconButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final focused = Focus.of(context).hasFocus;
    return Semantics(
      button: true,
      label: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: focused ? Ui.focusBorder : Colors.transparent,
                width: 3,
              ),
            ),
            child: Material(
              color: Colors.black45,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onPressed,
                child: SizedBox(
                  width: Ui.minTouchTarget,
                  height: Ui.minTouchTarget,
                  child: Icon(icon, size: 38, color: color),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 18, color: Ui.textSecondary)),
        ],
      ),
    );
  }
}

/// Hộp thoại giọng nói: nghe → hiện kết quả TO → người dùng OK → thực hiện.
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
    final cmd = _command;
    return Dialog(
      backgroundColor: Ui.surface,
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _listening ? Icons.mic : Icons.hearing,
              size: 72,
              color: Ui.accent,
            ),
            const SizedBox(height: 16),
            Text(
              _listening ? 'Xin mời nói...' : 'Bạn vừa nói:',
              style: const TextStyle(fontSize: 24, color: Ui.textSecondary),
            ),
            const SizedBox(height: 12),
            Text(
              _heard.isEmpty ? '...' : _heard,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Ui.textPrimary),
            ),
            if (cmd != null && !cmd.isUnknown) ...[
              const SizedBox(height: 16),
              Text(
                cmd.confirmation,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 26, color: Ui.accent),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(fontSize: 24),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(cmd);
                    },
                    child: const Text('Đồng ý'),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(fontSize: 24),
                    ),
                    onPressed: _start,
                    child: const Text('Nói lại'),
                  ),
                ],
              ),
            ] else if (!_listening) ...[
              const SizedBox(height: 16),
              const Text('Không hiểu lệnh. Thử nói: "Bật VTV3"',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, color: Ui.textSecondary)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(fontSize: 24),
                    ),
                    onPressed: _start,
                    child: const Text('Nói lại'),
                  ),
                  const SizedBox(width: 16),
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      textStyle: const TextStyle(fontSize: 24),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Đóng'),
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
