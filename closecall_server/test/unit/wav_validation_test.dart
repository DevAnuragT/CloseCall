import 'dart:typed_data';

import 'package:closecall_server/src/generated/protocol.dart';
import 'package:closecall_server/src/moments/wav_validation.dart';
import 'package:test/test.dart';

import '../support/moment_wav.dart';

void main() {
  final invalid = throwsA(
    isA<MomentFailure>().having((e) => e.code, 'code', 'invalid_voice'),
  );
  test(
    'actual PCM frames define duration; offset views and 30 second boundary work',
    () {
      expect(validateMomentWav(momentWav()), 100);
      expect(validateMomentWav(momentWav(frames: 1)), 1);
      expect(validateMomentWav(momentWav(frames: 480000)), 30000);
      final wrapped = Uint8List.fromList([
        1,
        2,
        ...momentBytes(momentWav()),
        3,
      ]);
      expect(
        validateMomentWav(ByteData.sublistView(wrapped, 2, wrapped.length - 1)),
        100,
      );
      expect(() => validateMomentWav(momentWav(frames: 480001)), invalid);
    },
  );
  test(
    'rejects format spoofing, inconsistent headers, truncation and empty frames',
    () {
      for (final edit in <void Function(ByteData)>[
        (d) => d.setUint8(0, 0),
        (d) => d.setUint32(4, 1, Endian.little),
        (d) => d.setUint8(8, 0),
        (d) => d.setUint32(16, 0xffffffff, Endian.little),
        (d) => d.setUint16(20, 3, Endian.little),
        (d) => d.setUint16(22, 2, Endian.little),
        (d) => d.setUint32(24, 44100, Endian.little),
        (d) => d.setUint32(28, 64000, Endian.little),
        (d) => d.setUint16(32, 4, Endian.little),
        (d) => d.setUint16(34, 8, Endian.little),
        (d) => d.setUint32(40, 1, Endian.little),
        (d) => d.setUint32(40, 0xffffffff, Endian.little),
      ]) {
        final wav = momentWav();
        edit(wav);
        expect(() => validateMomentWav(wav), invalid);
      }
      for (final data in [
        ByteData(0),
        ByteData(100),
        momentWav(frames: 0),
        ByteData.sublistView(momentBytes(momentWav()), 0, 43),
      ]) {
        expect(() => validateMomentWav(data), invalid);
      }
      expect(
        () => validateMomentWav(ByteData(1024 * 1024 + 1)),
        throwsA(
          isA<MomentFailure>().having((e) => e.code, 'code', 'file_too_large'),
        ),
      );
    },
  );
  test(
    'RIFF ancillary chunks honor padding, duplicate fmt/data and trailing garbage fail',
    () {
      final original = momentBytes(momentWav());
      // Odd ancillary chunk with required one-byte pad between fmt and data.
      final bytes = Uint8List.fromList([
        ...original.sublist(0, 36),
        ...'JUNK'.codeUnits,
        1,
        0,
        0,
        0,
        7,
        0,
        ...original.sublist(36),
      ]);
      final wav = ByteData.sublistView(bytes);
      wav.setUint32(4, bytes.length - 8, Endian.little);
      expect(validateMomentWav(wav), 100);
      for (final extra in [
        original.sublist(12, 36),
        original.sublist(36),
        [7],
        [...'JUNK'.codeUnits, 1, 0, 0, 0, 7],
      ]) {
        final appended = ByteData.sublistView(
          Uint8List.fromList([...original, ...extra]),
        );
        appended.setUint32(4, appended.lengthInBytes - 8, Endian.little);
        expect(() => validateMomentWav(appended), invalid);
      }
    },
  );
}
