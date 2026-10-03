import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:closecall_client/closecall_client.dart';
import 'package:closecall/features/auth/data/auth_session.dart';
import 'package:closecall/features/couple/data/couple_repository.dart';
import 'package:closecall/features/couple/domain/couple.dart';
import 'package:closecall/features/media/data/media_repository.dart';

final testPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4v+rMfwAIlgN1QhRUCQAAAABJRU5ErkJggg==',
);

class FakeAuth extends AuthSession {
  String? identity;
  AccountState? account;
  Completer<AccountState?>? pendingAccount;
  Object? accountFailure;
  int signOuts = 0;
  @override
  String? get userId => identity;
  void change(String? value) {
    identity = value;
    notifyListeners();
  }

  @override
  Future<void> initialize() async {}
  @override
  Future<void> signInAnonymously() async => change('guest');
  @override
  Future<void> signOut() async {
    signOuts++;
    change(null);
  }

  @override
  Future<AccountState?> currentAccount() async {
    if (accountFailure != null) throw accountFailure!;
    return pendingAccount == null ? account : pendingAccount!.future;
  }
}

class FakeCouples implements CoupleRepository {
  Couple? couple = Couple(id: 'couple', memberIds: ['me', 'partner']);
  @override
  Future<Couple?> coupleForUser(String id) async => couple;
  @override
  Future<PairingResult> createCouple(String userId) async =>
      throw UnimplementedError();
  @override
  Future<Couple> joinByCode(String userId, String code) async => couple!;
}

MediaAsset testAsset({
  String id = 'asset',
  String uploader = 'partner',
  String couple = 'couple',
}) => MediaAsset(
  assetId: id,
  coupleId: couple,
  uploaderId: uploader,
  createdAt: DateTime.utc(2026, 10, 3),
  width: 1,
  height: 1,
);

class FakeMedia implements MediaRepository {
  List<MediaAsset> assets = [testAsset()];
  Object? uploadFailure;
  Object? listFailure;
  Object? downloadFailure;
  Completer<List<MediaAsset>>? pendingList;
  Completer<Uint8List>? pendingDownload;
  final requestIds = <String>[];
  final payloads = <Uint8List>[];
  final downloads = <String>[];
  @override
  Future<MediaAsset> uploadPhoto(Uint8List bytes, String requestId) async {
    requestIds.add(requestId);
    payloads.add(Uint8List.fromList(bytes));
    if (uploadFailure != null) throw uploadFailure!;
    return testAsset(id: 'uploaded', uploader: 'me');
  }

  @override
  Future<List<MediaAsset>> listAssets() async {
    if (listFailure != null) throw listFailure!;
    return pendingList == null ? assets : pendingList!.future;
  }

  @override
  Future<Uint8List> downloadPhoto(String assetId) async {
    downloads.add(assetId);
    if (downloadFailure != null) throw downloadFailure!;
    return pendingDownload == null ? testPng : pendingDownload!.future;
  }
}
