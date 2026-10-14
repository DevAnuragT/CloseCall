import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

const maxMomentVoiceBytes = 1024 * 1024;
const maxMomentPcmBytes = 16000 * 2 * 30;

/// Native calls are serialized by MomentsController. Recording is streamed into
/// bounded memory; playback uses only an app-private, short-lived WAV file.
abstract interface class MomentAudio {
  Stream<void> get completed;
  Future<Stream<Uint8List>> startRecording();
  Future<void> stopRecording();
  Future<void> play(Uint8List wav);
  Future<void> stopPlayback();
  Future<void> dispose();
}

class PrivateMomentAudio implements MomentAudio {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  Directory? _directory;
  File? _playingFile;

  @override
  Stream<void> get completed => _player.onPlayerComplete;

  @override
  Future<Stream<Uint8List>> startRecording() async {
    // This method is called only by an explicit Record action.
    if (!await _recorder.hasPermission()) {
      throw StateError('Microphone permission was not granted.');
    }
    return _recorder.startStream(
      const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: false,
        echoCancel: false,
        noiseSuppress: false,
      ),
    );
  }

  @override
  Future<void> stopRecording() async {
    await _recorder.stop();
  }

  @override
  Future<void> play(Uint8List wav) async {
    await stopPlayback();
    final root = await getTemporaryDirectory();
    _directory = await Directory('${root.path}/closecall_moments').create();
    // Purge leftovers after an interrupted process; no shared/public media path.
    await for (final entity in _directory!.list()) {
      await entity.delete(recursive: true);
    }
    _playingFile = File('${_directory!.path}/voice.wav');
    try {
      await _playingFile!.writeAsBytes(wav, flush: true);
      await _player.setReleaseMode(ReleaseMode.stop);
      await _player.play(DeviceFileSource(_playingFile!.path));
    } catch (_) {
      await stopPlayback();
      rethrow;
    }
  }

  @override
  Future<void> stopPlayback() async {
    try {
      await _player.stop();
    } finally {
      // Also remove leftovers from an interrupted process on the next scope
      // cleanup, even if this adapter has not played a file in this process.
      final directory =
          _directory ??
          Directory(
            '${(await getTemporaryDirectory()).path}/closecall_moments',
          );
      _playingFile = null;
      _directory = null;
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    }
  }

  @override
  Future<void> dispose() async {
    try {
      await stopRecording();
    } catch (_) {}
    try {
      await stopPlayback();
    } finally {
      try {
        await _recorder.dispose();
      } finally {
        await _player.dispose();
      }
    }
  }
}

Uint8List momentWav(Uint8List pcm) {
  if (pcm.isEmpty || pcm.length.isOdd || pcm.length > maxMomentPcmBytes) {
    throw const FormatException('Voice must be between 0 and 30 seconds.');
  }
  final bytes = Uint8List(44 + pcm.length);
  final data = ByteData.sublistView(bytes);
  void tag(int offset, String value) =>
      bytes.setRange(offset, offset + value.length, value.codeUnits);
  tag(0, 'RIFF');
  data.setUint32(4, bytes.length - 8, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, pcm.length, Endian.little);
  bytes.setRange(44, bytes.length, pcm);
  return bytes;
}

/// Check all downloaded/recorded audio before giving it to a native decoder.
int validateMomentWav(Uint8List bytes) {
  if (bytes.length < 44 || bytes.length > maxMomentVoiceBytes) {
    throw const FormatException('Invalid voice size.');
  }
  final d = ByteData.sublistView(bytes);
  String tag(int n) => String.fromCharCodes(bytes.sublist(n, n + 4));
  if (tag(0) != 'RIFF' ||
      tag(8) != 'WAVE' ||
      d.getUint32(4, Endian.little) != bytes.length - 8) {
    throw const FormatException('Invalid WAV.');
  }
  bool format = false;
  int? pcmLength;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final size = d.getUint32(offset + 4, Endian.little);
    final start = offset + 8;
    if (start + size > bytes.length) {
      throw const FormatException('Invalid WAV.');
    }
    if (tag(offset) == 'fmt ') {
      if (format ||
          (size != 16 && size != 18) ||
          d.getUint16(start, Endian.little) != 1 ||
          d.getUint16(start + 2, Endian.little) != 1 ||
          d.getUint32(start + 4, Endian.little) != 16000 ||
          d.getUint32(start + 8, Endian.little) != 32000 ||
          d.getUint16(start + 12, Endian.little) != 2 ||
          d.getUint16(start + 14, Endian.little) != 16 ||
          (size == 18 && d.getUint16(start + 16, Endian.little) != 0)) {
        throw const FormatException(
          'Voice must be mono 16-bit PCM at 16000 Hz.',
        );
      }
      format = true;
    } else if (tag(offset) == 'data') {
      if (!format || pcmLength != null) {
        throw const FormatException('Invalid WAV.');
      }
      pcmLength = size;
    }
    offset = start + size + (size.isOdd ? 1 : 0);
  }
  if (!format ||
      pcmLength == null ||
      pcmLength == 0 ||
      pcmLength.isOdd ||
      pcmLength > maxMomentPcmBytes ||
      offset != bytes.length) {
    throw const FormatException('Voice must be between 0 and 30 seconds.');
  }
  return (pcmLength * 1000 + 31999) ~/ 32000;
}
