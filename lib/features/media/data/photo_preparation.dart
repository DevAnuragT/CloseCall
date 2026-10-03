import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'media_repository.dart';

const maxPhotoBytes = 2 * 1024 * 1024;
const maxPhotoDimension = 2048;

/// Bounds encoded input, source pixels and decoded output before PNG encoding.
/// Oversized PNG output is resized in at most eight steps, never sent as JPEG.
Future<Uint8List> preparePhotoPng(Uint8List input) async {
  if (input.isEmpty || input.length > 20 * 1024 * 1024) {
    throw const FormatException('Selected photo is empty or exceeds 20 MiB.');
  }
  final buffer = await ui.ImmutableBuffer.fromUint8List(input);
  ui.ImageDescriptor? descriptor;
  try {
    descriptor = await ui.ImageDescriptor.encoded(buffer);
    if (descriptor.width * descriptor.height > 40 * 1024 * 1024) {
      throw const FormatException(
        'Selected photo exceeds the 40-megapixel source limit.',
      );
    }
    var scale = math.min(
      1.0,
      maxPhotoDimension / math.max(descriptor.width, descriptor.height),
    );
    for (var attempt = 0; attempt < 8; attempt++) {
      final codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * scale).floor()),
        targetHeight: math.max(1, (descriptor.height * scale).floor()),
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final data = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (data == null) {
            throw const FormatException('Could not encode photo as PNG.');
          }
          if (data.lengthInBytes <= maxPhotoBytes) {
            return Uint8List.fromList(byteDataBytes(data));
          }
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
      scale *= 0.75;
    }
    throw const FormatException(
      'Could not reduce PNG below 2 MiB. Choose a simpler photo.',
    );
  } finally {
    descriptor?.dispose();
    buffer.dispose();
  }
}

/// Cheap explicit check at the upload boundary, even with injected preparation.
void validateUploadPng(Uint8List bytes) {
  const signature = [137, 80, 78, 71, 13, 10, 26, 10];
  if (bytes.length > maxPhotoBytes) {
    throw const FormatException('PNG exceeds the 2 MiB upload limit.');
  }
  if (bytes.length < 24 ||
      !List.generate(8, (i) => bytes[i] == signature[i]).every((v) => v) ||
      String.fromCharCodes(bytes.sublist(12, 16)) != 'IHDR') {
    throw const FormatException('Photo must be a valid PNG.');
  }
  final header = ByteData.sublistView(bytes);
  final width = header.getUint32(16);
  final height = header.getUint32(20);
  if (width < 1 ||
      height < 1 ||
      width > maxPhotoDimension ||
      height > maxPhotoDimension) {
    throw const FormatException(
      'PNG dimensions must be between 1 and 2048 pixels.',
    );
  }
}
