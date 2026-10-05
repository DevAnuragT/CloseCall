import 'dart:async';
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
      _ => 'The private photo request could not be completed. Try again.',
    };
  }
  if (failure is ServerpodClientNetworkException ||
      failure is TimeoutException) {
    return 'The connection was interrupted or timed out. An upload may have '
        'succeeded. Retry the same upload or refresh private photos to check.';
  }
  if (failure is FormatException) {
    // FormatException can also come from a remote response or image decoder.
    // Never echo its message/source as if it were trusted local validation.
    return 'Choose a valid photo. The prepared PNG must be at most 2 MiB '
        'and no larger than 2048 × 2048 pixels.';
  }
  if (failure is StateError) {
    // Only these controller-owned messages are safe to show verbatim.
    switch (failure.message) {
      case 'Complete pairing before sharing photos.':
      case 'Retry or cancel the pending upload before choosing another photo.':
      case 'Photo is outside this couple.':
      case 'No downloaded photo or local widget adapter.':
        return failure.message;
    }
  }
  return 'Could not confirm the photo operation. An upload may have succeeded. '
      'Retry the same upload or refresh private photos to check.';
}
