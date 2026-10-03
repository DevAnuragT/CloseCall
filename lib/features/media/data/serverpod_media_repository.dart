import 'dart:typed_data';
import 'package:closecall_client/closecall_client.dart';
import 'media_repository.dart';

class ServerpodMediaRepository implements MediaRepository {
  ServerpodMediaRepository(this.client);
  final Client client;
  @override
  Future<MediaAsset> uploadPhoto(Uint8List bytes, String requestId) =>
      client.media.uploadPhoto(ByteData.sublistView(bytes), requestId);
  @override
  Future<List<MediaAsset>> listAssets() => client.media.listAssets();
  @override
  Future<Uint8List> downloadPhoto(String assetId) async => Uint8List.fromList(
    byteDataBytes(await client.media.downloadPhoto(assetId)),
  );
}
