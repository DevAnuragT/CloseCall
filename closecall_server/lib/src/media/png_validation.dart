import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as image;

import '../generated/protocol.dart';

/// Preflights dimensions, chunk structure/CRCs and bounded zlib output BEFORE
/// the image decoder allocates pixels. Only a single still PNG is accepted.
({int width, int height}) validatePng(ByteData data) {
  if (data.lengthInBytes > 2 * 1024 * 1024) {
    throw MediaFailure(code: 'file_too_large');
  }
  final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  try {
    if (bytes.length < 45 ||
        !List.generate(8, (i) => bytes[i] == signature[i]).every((e) => e) ||
        data.getUint32(8) != 13 ||
        String.fromCharCodes(bytes.sublist(12, 16)) != 'IHDR') {
      throw const FormatException();
    }
    final width = data.getUint32(16);
    final height = data.getUint32(20);
    if (width < 1 || height < 1 || width > 2048 || height > 2048) {
      throw const FormatException();
    }
    final depth = bytes[24];
    final color = bytes[25];
    final channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}[color];
    final depths = switch (color) {
      0 => [1, 2, 4, 8, 16],
      3 => [1, 2, 4, 8],
      2 || 4 || 6 => [8, 16],
      _ => <int>[],
    };
    if (channels == null ||
        !depths.contains(depth) ||
        bytes[26] != 0 ||
        bytes[27] != 0 ||
        bytes[28] > 1) {
      throw const FormatException();
    }
    final compressed = BytesBuilder(copy: false);
    var offset = 8;
    var sawData = false;
    var endedData = false;
    var sawEnd = false;
    var sawPalette = false;
    var sawTransparency = false;
    var paletteEntries = 0;
    while (offset + 12 <= bytes.length) {
      final length = data.getUint32(offset);
      final end = offset + 12 + length;
      if (end > bytes.length) throw const FormatException();
      final typeBytes = bytes.sublist(offset + 4, offset + 8);
      if (!typeBytes.every(
            (c) => (c >= 65 && c <= 90) || (c >= 97 && c <= 122),
          ) ||
          (typeBytes[2] & 32) != 0) {
        throw const FormatException();
      }
      final type = String.fromCharCodes(typeBytes);
      if (_crc32(bytes, offset + 4, end - 4) != data.getUint32(end - 4)) {
        throw const FormatException();
      }
      if (type == 'IHDR' && offset != 8 ||
          const ['acTL', 'fcTL', 'fdAT'].contains(type)) {
        throw const FormatException();
      }
      if (type == 'IDAT') {
        if (endedData) throw const FormatException();
        sawData = true;
        compressed.add(Uint8List.sublistView(bytes, offset + 8, end - 4));
      } else if (sawData) {
        endedData = true;
      }
      if (type == 'PLTE') {
        if (sawData ||
            sawPalette ||
            length == 0 ||
            length > 768 ||
            length % 3 != 0) {
          throw const FormatException();
        }
        if (color == 0 ||
            color == 4 ||
            (color == 3 && length ~/ 3 > 1 << depth)) {
          throw const FormatException();
        }
        paletteEntries = length ~/ 3;
        sawPalette = true;
      }
      if (type == 'tRNS') {
        if (sawData ||
            sawTransparency ||
            (color == 0 && length != 2) ||
            (color == 2 && length != 6) ||
            (color == 3 &&
                (!sawPalette || length == 0 || length > paletteEntries)) ||
            color == 4 ||
            color == 6) {
          throw const FormatException();
        }
        sawTransparency = true;
      }
      const retained = ['IHDR', 'PLTE', 'tRNS', 'IDAT', 'IEND'];
      if (!retained.contains(type) && (typeBytes[0] & 32) == 0) {
        throw const FormatException(); // Unknown critical chunk.
      }
      if (type == 'IEND') {
        if (length != 0 || end != bytes.length || !sawData) {
          throw const FormatException();
        }
        sawEnd = true;
        break;
      }
      offset = end;
    }
    if (!sawEnd || color == 3 && !sawPalette) throw const FormatException();
    var expected = 0;
    void pass(int x, int y, int dx, int dy) {
      if (width <= x || height <= y) return;
      final w = (width - x + dx - 1) ~/ dx;
      final h = (height - y + dy - 1) ~/ dy;
      expected += h * (1 + (w * channels * depth + 7) ~/ 8);
    }

    if (bytes[28] == 0) {
      pass(0, 0, 1, 1);
    } else {
      for (final p in const [
        [0, 0, 8, 8],
        [4, 0, 8, 8],
        [0, 4, 4, 8],
        [2, 0, 4, 4],
        [0, 2, 2, 4],
        [1, 0, 2, 2],
        [0, 1, 1, 2],
      ]) {
        pass(p[0], p[1], p[2], p[3]);
      }
    }
    final counter = _BoundedInflation(expected);
    final inflate = ZLibDecoder().startChunkedConversion(counter);
    final input = compressed.takeBytes();
    for (var i = 0; i < input.length; i += 4096) {
      inflate.add(
        Uint8List.sublistView(input, i, (i + 4096).clamp(0, input.length)),
      );
    }
    inflate.close();
    if (counter.length != expected) throw const FormatException();
    // Decode the original file, not just its header or a thumbnail. In the
    // pinned decoder ICC profiles remain compressed and ancillary allocations
    // are bounded by the 2 MiB input. Pixel inflation was bounded above.
    final decoded = image.decodePng(bytes);
    if (decoded == null || decoded.width != width || decoded.height != height) {
      throw const FormatException();
    }
    return (width: width, height: height);
  } catch (_) {
    throw MediaFailure(code: 'invalid_image');
  }
}

class _BoundedInflation implements Sink<List<int>> {
  _BoundedInflation(this.maximum);
  final int maximum;
  int length = 0;
  @override
  void add(List<int> data) {
    length += data.length;
    if (length > maximum) throw const FormatException();
  }

  @override
  void close() {}
}

final _crcTable = List<int>.generate(256, (n) {
  var crc = n;
  for (var i = 0; i < 8; i++) {
    crc = crc & 1 != 0 ? 0xedb88320 ^ (crc >> 1) : crc >> 1;
  }
  return crc;
});

int _crc32(Uint8List bytes, int start, int end) {
  var crc = 0xffffffff;
  for (var i = start; i < end; i++) {
    crc = _crcTable[(crc ^ bytes[i]) & 0xff] ^ (crc >> 8);
  }
  return crc ^ 0xffffffff;
}
