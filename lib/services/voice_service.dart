import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../models.dart';

/// Giọng nói tiếng Việt — tìm kiếm & lệnh nhanh, dùng engine có sẵn trên máy
/// (Google trên Android, Siri trên iOS) → không cần server, miễn phí.
class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;

  bool get isListening => _speech.isListening;

  /// Khởi tạo + xin quyền micro (gọi 1 lần, hiện hộp thoại hệ thống).
  Future<bool> init() async {
    if (_available) return true;
    _available = await _speech.initialize(
      onError: (e) {},
      onStatus: (s) {},
    );
    return _available;
  }

  /// Nghe 1 câu tiếng Việt, trả về text nhận dạng được.
  Future<String?> listenOnce({
    void Function(String text)? onPartial,
  }) async {
    if (!await init()) return null;
    final completerResult = await _speech.listen(
      localeId: 'vi_VN',
      listenOptions: stt.ListenOptions(
        cancelOnError: true,
        partialResults: onPartial != null,
        listenMode: stt.ListenMode.dictation,
      ),
      onResult: (r) {
        if (onPartial != null && !r.finalResult && r.recognizedWords.isNotEmpty) {
          onPartial(r.recognizedWords);
        }
      },
    );
    return completerResult;
  }

  Future<void> stop() => _speech.stop();

  /// Phân tích câu nói thành lệnh.
  /// Hỗ trợ: "bật VTV3" / "xem VTV1" / "mở nhạc trữ tình" / "về kênh trước"...
  static VoiceCommand parse(String text, AppConfig config) {
    final t = text.toLowerCase().trim();

    // Lệnh chuyển kênh
    if (t.contains('kênh trước') || t.contains('ve kenh truoc')) {
      return VoiceCommand(type: VoiceCommandType.prevChannel);
    }
    if (t.contains('kênh sau') || t.contains('kenh sau') || t.contains('kế tiếp')) {
      return VoiceCommand(type: VoiceCommandType.nextChannel);
    }

    // "bật/mở/xem VTV3", "chuyển kênh 3"...
    final channelMatch = RegExp(
            r'(?:bật|mở|xem|chuyển|về)\s*(?:kênh\s*)?(.+)',
            caseSensitive: false)
        .firstMatch(t);
    if (channelMatch != null) {
      final target = channelMatch.group(1) ?? '';
      final ch = config.findChannelByName(target);
      if (ch != null) {
        return VoiceCommand(type: VoiceCommandType.playChannel, channel: ch);
      }
      final cat = config.findCategoryByName(target);
      if (cat != null) {
        return VoiceCommand(type: VoiceCommandType.openCategory, category: cat);
      }
    }

    // Chỉ nói tên kênh: "vtv3"
    final ch = config.findChannelByName(t);
    if (ch != null) {
      return VoiceCommand(type: VoiceCommandType.playChannel, channel: ch);
    }

    // Chỉ nói tên danh mục: "nhạc trữ tình"
    final cat = config.findCategoryByName(t);
    if (cat != null) {
      return VoiceCommand(type: VoiceCommandType.openCategory, category: cat);
    }

    return VoiceCommand(type: VoiceCommandType.unknown, rawText: text);
  }
}

enum VoiceCommandType {
  playChannel,
  openCategory,
  nextChannel,
  prevChannel,
  unknown,
}

class VoiceCommand {
  final VoiceCommandType type;
  final Channel? channel;
  final YouTubeCategory? category;
  final String rawText;

  VoiceCommand({
    required this.type,
    this.channel,
    this.category,
    this.rawText = '',
  });

  /// Câu xác nhận hiện to cho người dùng kiểm tra trước khi thực hiện.
  String get confirmation {
    switch (type) {
      case VoiceCommandType.playChannel:
        return 'Bạn muốn xem: ${channel!.name}';
      case VoiceCommandType.openCategory:
        return 'Bạn muốn mở: ${category!.name}';
      case VoiceCommandType.nextChannel:
        return 'Chuyển kênh sau';
      case VoiceCommandType.prevChannel:
        return 'Về kênh trước';
      case VoiceCommandType.unknown:
        return 'Không hiểu: "$rawText"';
    }
  }

  bool get isUnknown => type == VoiceCommandType.unknown;
}
