import 'dart:typed_data';

import '../generated/protocol.dart';

/// Validates the actual RIFF container and PCM frames, never client metadata.
/// Accepts ancillary RIFF chunks (including padding), but only one fmt/data pair.
int validateMomentWav(ByteData bytes) {
  Never invalid() => throw MomentFailure(code: 'invalid_voice');
  if (bytes.lengthInBytes > 1024 * 1024) {
    throw MomentFailure(code: 'file_too_large');
  }
  if (bytes.lengthInBytes < 44) invalid();
  bool tag(int at, String value) {
    for (var i = 0; i < value.length; i++) {
      if (bytes.getUint8(at + i) != value.codeUnitAt(i)) return false;
    }
    return true;
  }

  if (!tag(0, 'RIFF') ||
      !tag(8, 'WAVE') ||
      bytes.getUint32(4, Endian.little) != bytes.lengthInBytes - 8) {
    invalid();
  }
  var offset = 12;
  var format = false;
  int? dataLength;
  while (offset < bytes.lengthInBytes) {
    if (bytes.lengthInBytes - offset < 8) invalid();
    final size = bytes.getUint32(offset + 4, Endian.little);
    final start = offset + 8;
    final end = start + size;
    final paddedEnd = end + (size & 1);
    if (paddedEnd > bytes.lengthInBytes) invalid();
    if (tag(offset, 'fmt ')) {
      if (format || (size != 16 && size != 18)) invalid();
      if (bytes.getUint16(start, Endian.little) != 1 ||
          bytes.getUint16(start + 2, Endian.little) != 1 ||
          bytes.getUint32(start + 4, Endian.little) != 16000 ||
          bytes.getUint32(start + 8, Endian.little) != 32000 ||
          bytes.getUint16(start + 12, Endian.little) != 2 ||
          bytes.getUint16(start + 14, Endian.little) != 16 ||
          (size == 18 && bytes.getUint16(start + 16, Endian.little) != 0)) {
        invalid();
      }
      format = true;
    } else if (tag(offset, 'data')) {
      if (!format ||
          dataLength != null ||
          size == 0 ||
          size.isOdd ||
          size > 30 * 32000) {
        invalid();
      }
      dataLength = size;
    }
    offset = paddedEnd;
  }
  if (!format || dataLength == null) invalid();
  // Round up sub-millisecond clips so a nonempty recording has positive duration.
  return (dataLength * 1000 + 31999) ~/ 32000;
}
