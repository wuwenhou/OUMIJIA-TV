// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:typed_data';

/// Liệt kê track/codec trong file MP4/fMP4 (init segment).
/// Chạy: `dart run tool/mp4_probe.dart <file.mp4> [file2.mp4 ...]`
void main(List<String> args) {
  for (final path in args) {
    final bytes = File(path).readAsBytesSync();
    print('=== $path (${bytes.length} bytes)');
    _dump(bytes, _parse(bytes, 0, bytes.length, 0), 0);
  }
}

class Box {
  final String type;
  final int offset;
  final int size;
  final List<Box> children;
  Box(this.type, this.offset, this.size, this.children);
}

List<Box> _parse(Uint8List b, int start, int end, int depth) {
  final out = <Box>[];
  var pos = start;
  while (pos + 8 <= end) {
    var size = _u32(b, pos);
    final type = String.fromCharCodes(b.sublist(pos + 4, pos + 8));
    var header = 8;
    if (size == 1) {
      if (pos + 16 > end) break;
      size = _u64(b, pos + 8);
      header = 16;
    } else if (size == 0) {
      size = end - pos;
    }
    if (size < header || pos + size > end) break;
    const childTypes = {
      'moov', 'trak', 'mdia', 'minf', 'stbl', 'stsd', 'mvex', 'moof', 'traf',
      'edts', 'dinf', 'udta', 'meta', 'ilst', 'sinf', 'schi', 'wave',
    };
    var children = const <Box>[];
    if (childTypes.contains(type)) {
      var cs = pos + header;
      if (type == 'stsd') cs += 8; // version/flags + entry_count
      if (type == 'meta') cs += 4; // fullbox header
      children = _parse(b, cs, pos + size, depth + 1);
    }
    out.add(Box(type, pos, size, children));
    pos += size;
  }
  return out;
}

void _dump(Uint8List b, List<Box> boxes, int depth) {
  final pad = '  ' * depth;
  for (final box in boxes) {
    var extra = '';
    if (box.type == 'hdlr') {
      final p = box.offset + 8;
      if (p + 12 <= box.offset + box.size) {
        extra = ' handler=${String.fromCharCodes(b.sublist(p + 8, p + 12))}';
      }
    }
    if (box.type == 'stsd') {
      final p = box.offset + 8 + 8;
      if (p + 8 <= box.offset + box.size) {
        extra = ' codec=${String.fromCharCodes(b.sublist(p + 4, p + 8))}';
      }
    }
    print('$pad${box.type} size=${box.size}$extra');
    _dump(b, box.children, depth + 1);
  }
}

int _u32(Uint8List b, int i) =>
    (b[i] << 24) | (b[i + 1] << 16) | (b[i + 2] << 8) | b[i + 3];

int _u64(Uint8List b, int i) =>
    (_u32(b, i) * 0x100000000) + _u32(b, i + 4);
