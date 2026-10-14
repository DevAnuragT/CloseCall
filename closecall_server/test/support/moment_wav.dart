import 'dart:typed_data';

ByteData momentWav({int frames = 1600, int sample = 0}) {
  final wav = ByteData(44 + frames * 2);
  void tag(int offset, String text) {
    for (var i = 0; i < text.length; i++) {
      wav.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  wav.setUint32(4, wav.lengthInBytes - 8, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  wav.setUint32(16, 16, Endian.little);
  wav.setUint16(20, 1, Endian.little);
  wav.setUint16(22, 1, Endian.little);
  wav.setUint32(24, 16000, Endian.little);
  wav.setUint32(28, 32000, Endian.little);
  wav.setUint16(32, 2, Endian.little);
  wav.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  wav.setUint32(40, frames * 2, Endian.little);
  for (var at = 44; at < wav.lengthInBytes; at += 2) {
    wav.setInt16(at, sample, Endian.little);
  }
  return wav;
}

Uint8List momentBytes(ByteData data) =>
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
