import 'dart:typed_data';

import 'package:closecall_client/closecall_client.dart' as api;

abstract interface class MomentsRepository {
  Future<List<api.MomentEntry>> list({String? beforeId, int limit = 20});
  Future<api.MomentEntry> create({
    required String requestId,
    required String text,
    ByteData? voiceBytes,
  });
  Future<ByteData> downloadVoice(String momentId);
  Future<void> delete(String momentId);
}

class ServerpodMomentsRepository implements MomentsRepository {
  ServerpodMomentsRepository(this.client);
  final api.Client client;

  @override
  Future<List<api.MomentEntry>> list({String? beforeId, int limit = 20}) =>
      client.moments.listMoments(beforeId: beforeId, limit: limit);

  @override
  Future<api.MomentEntry> create({
    required String requestId,
    required String text,
    ByteData? voiceBytes,
  }) => client.moments.createMoment(
    requestId: requestId,
    text: text,
    voiceBytes: voiceBytes,
  );

  @override
  Future<ByteData> downloadVoice(String momentId) =>
      client.moments.downloadVoice(momentId: momentId);

  @override
  Future<void> delete(String momentId) =>
      client.moments.deleteMoment(momentId: momentId);
}
