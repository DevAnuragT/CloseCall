import 'dart:typed_data';
import 'package:closecall_client/closecall_client.dart';

/// Uses generated wire types, not parallel copies of backend DTOs.
abstract interface class MediaRepository {
  Future<MediaAsset> uploadPhoto(Uint8List pngBytes, String requestId);
  Future<List<MediaAsset>> listAssets();
  Future<Uint8List> downloadPhoto(String assetId);
}

Uint8List byteDataBytes(ByteData data) =>
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

String mediaErrorMessage(Object failure) {
  if (failure is MediaFailure) {
    return switch (failure.code) {
      'invalid_image' => 'Use a valid PNG image no larger than 2048 × 2048.',
      'file_too_large' =>
        'The PNG must be at most 2 MiB. Choose a smaller photo.',
      'invalid_request_id' =>
        'The upload request ID was rejected. Cancel and choose the photo again.',
      'request_conflict' =>
        'This request ID belongs to a different photo. Cancel and start again.',
      'asset_not_found' =>
        'That private photo is no longer available. Refresh the list.',
      'not_paired' => 'Complete pairing before sharing private photos.',
      'quota_exceeded' => 'Your private photo storage quota has been reached.',
      _ => 'Private media request failed: ${failure.code}',
    };
  }
  return 'Photo operation failed: $failure';
}
