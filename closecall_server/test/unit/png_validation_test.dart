import 'dart:io';
import 'dart:typed_data';

import 'package:closecall_server/src/generated/protocol.dart';
import 'package:closecall_server/src/media/png_validation.dart';
import 'package:image/image.dart' as image;
import 'package:test/test.dart';

ByteData _png({
  int width = 1,
  int height = 1,
  List<int>? raw,
  List<int>? extra,
}) {
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 2);
  final bytes = BytesBuilder()
    ..add([137, 80, 78, 71, 13, 10, 26, 10])
    ..add(_chunk('IHDR', header.buffer.asUint8List()));
  if (extra != null) bytes.add(extra);
  bytes
    ..add(_chunk('IDAT', ZLibEncoder().convert(raw ?? [0, 10, 20, 30])))
    ..add(_chunk('IEND', []));
  return ByteData.sublistView(bytes.takeBytes());
}

List<int> _chunk(String type, List<int> data) {
  final payload = [...type.codeUnits, ...data];
  var crc = 0xffffffff;
  for (final byte in payload) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = crc & 1 != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  final result = ByteData(data.length + 12)
    ..setUint32(0, data.length)
    ..setUint32(data.length + 8, crc ^ 0xffffffff);
  result.buffer.asUint8List().setRange(4, data.length + 8, payload);
  return result.buffer.asUint8List();
}

void main() {
  final invalid = throwsA(
    isA<MediaFailure>().having((e) => e.code, 'code', 'invalid_image'),
  );
  test('fully decodes PNGs and respects ByteData view offsets', () {
    final png = image.encodePng(image.Image(width: 2048, height: 1));
    final backing = Uint8List(png.length + 200)
      ..setRange(100, png.length + 100, png);
    final validated = validatePng(
      ByteData.sublistView(backing, 100, png.length + 100),
    );
    expect(validated, (width: 2048, height: 1));
  });
  test('valid-CRC malicious dimensions rejected before decoder allocation', () {
    for (final size in [0, 2049, 0x7fffffff, 0xffffffff]) {
      expect(() => validatePng(_png(width: size)), invalid);
      expect(() => validatePng(_png(height: size)), invalid);
    }
  });
  test(
    'bounded inflate rejects tiny-header decompression bombs and truncation',
    () {
      expect(
        () => validatePng(_png(raw: List.filled(1024 * 1024, 0))),
        invalid,
      );
      expect(() => validatePng(_png(raw: [0, 10, 20])), invalid);
      expect(() => validatePng(_png(raw: [255, 10, 20, 30])), invalid);
    },
  );
  test(
    'APNG frame allocations, duplicate headers, unknown critical chunks rejected',
    () {
      expect(
        () => validatePng(_png(extra: _chunk('acTL', List.filled(8, 255)))),
        invalid,
      );
      expect(
        () => validatePng(_png(extra: _chunk('IHDR', List.filled(13, 0)))),
        invalid,
      );
      expect(() => validatePng(_png(extra: _chunk('BOOM', []))), invalid);
    },
  );
  test('all chunk CRCs and end-of-stream structure checked', () {
    final valid = _png();
    final corrupt = Uint8List.fromList(valid.buffer.asUint8List())..[45] ^= 1;
    expect(() => validatePng(ByteData.sublistView(corrupt)), invalid);
    final trailing = Uint8List.fromList([...valid.buffer.asUint8List(), 0]);
    expect(() => validatePng(ByteData.sublistView(trailing)), invalid);
  });
  test('2 MiB limit is inclusive, including ancillary metadata', () {
    final baseline = _png().lengthInBytes;
    final exact = _png(
      extra: _chunk('tEXt', List.filled(2 * 1024 * 1024 - baseline - 12, 0)),
    );
    expect(exact.lengthInBytes, 2 * 1024 * 1024);
    expect(validatePng(exact), (width: 1, height: 1));
    expect(
      () => validatePng(ByteData(2 * 1024 * 1024 + 1)),
      throwsA(
        isA<MediaFailure>().having((e) => e.code, 'code', 'file_too_large'),
      ),
    );
  });
}
