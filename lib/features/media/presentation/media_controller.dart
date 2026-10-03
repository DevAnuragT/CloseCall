import 'dart:async';
import 'package:closecall_client/closecall_client.dart' hide Uuid;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../pairing/presentation/pairing_controller.dart';
import '../data/media_repository.dart';
import '../data/photo_preparation.dart';

class MediaController extends ChangeNotifier {
  MediaController({
    required this.pairing,
    required this.repository,
    this.applyLocalPhoto,
    this.clearLocalPhoto,
    Future<Uint8List> Function(Uint8List)? prepare,
    String Function()? requestId,
  }) : _prepare = prepare ?? preparePhotoPng,
       _requestId = requestId ?? const Uuid().v4 {
    _scope = _currentScope;
    pairing.addListener(_scopeChanged);
    pairing.session.addListener(_scopeChanged);
  }
  final PairingController pairing;
  final MediaRepository repository;
  final Future<void> Function(Uint8List)? applyLocalPhoto;
  final Future<void> Function()? clearLocalPhoto;
  final Future<Uint8List> Function(Uint8List) _prepare;
  final String Function() _requestId;
  String? _scope;
  int _revision = 0;
  bool _disposed = false;
  bool busy = false;
  Object? error;
  String? status;
  List<MediaAsset> assets = [];
  Uint8List? downloadedPhoto;
  MediaAsset? selectedAsset;
  Uint8List? _pendingPhoto;
  bool _prepared = false;
  String? pendingRequestId;
  Future<void> Function()? _retry;
  Future<void> _localQueue = Future.value();
  bool get canShare => _currentScope != null;
  bool get hasPendingUpload => _pendingPhoto != null;
  String? get _currentScope =>
      pairing.userId != null && pairing.couple?.isComplete == true
      ? '${pairing.userId}/${pairing.couple!.id}'
      : null;
  bool _current(int revision) =>
      !_disposed && revision == _revision && _scope == _currentScope;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _scopeChanged() {
    if (_scope == _currentScope) return;
    final previous = _scope;
    _scope = _currentScope;
    _revision++;
    assets = [];
    downloadedPhoto = null;
    selectedAsset = null;
    _pendingPhoto = null;
    _prepared = false;
    pendingRequestId = null;
    _retry = null;
    error = null;
    status = null;
    busy = false;
    // Serialize cleanup after any in-flight native write, preventing old-user
    // photos from surviving sign-out or racing the next user's local update.
    if (previous != null && clearLocalPhoto != null) {
      final cleanupScope = _scope;
      _localQueue = _localQueue.then((_) => clearLocalPhoto!()).catchError((
        Object failure,
      ) {
        if (!_disposed && _scope == cleanupScope) {
          error = failure;
          _notify();
        }
      });
    }
    _notify();
    if (canShare) unawaited(refresh());
  }

  Future<void> _run(
    Future<void> Function(int) action,
    Future<void> Function() retry,
  ) async {
    if (_disposed || busy) return;
    if (!canShare) {
      error = StateError('Complete pairing before sharing photos.');
      _notify();
      return;
    }
    final revision = ++_revision;
    busy = true;
    error = null;
    status = null;
    _retry = retry;
    _notify();
    try {
      await action(revision);
      if (_current(revision)) _retry = null;
    } catch (failure) {
      if (_current(revision)) error = failure;
    } finally {
      if (_current(revision)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> uploadConfirmed(Uint8List photo) async {
    if (busy || _disposed) return;
    if (!canShare) {
      error = StateError('Complete pairing before sharing photos.');
      _notify();
      return;
    }
    if (hasPendingUpload) {
      error = StateError(
        'Retry or cancel the pending upload before choosing another photo.',
      );
      _notify();
      return;
    }
    // Preserve an immutable payload and UUID for retry after uncertain failures.
    _pendingPhoto = Uint8List.fromList(photo);
    _prepared = false;
    pendingRequestId = _requestId();
    await retryUpload();
  }

  Future<void> retryUpload() => _run((revision) async {
    if (_pendingPhoto == null || pendingRequestId == null) return;
    final original = _pendingPhoto!;
    final id = pendingRequestId!;
    final prepared = _prepared ? original : await _prepare(original);
    if (!_current(revision)) return;
    validateUploadPng(prepared);
    _pendingPhoto = prepared;
    _prepared = true;
    final result = await repository.uploadPhoto(prepared, id);
    if (!_current(revision)) return;
    _pendingPhoto = null;
    pendingRequestId = null;
    assets = [result, ...assets.where((a) => a.assetId != result.assetId)];
    status =
        'Uploaded privately to your couple. Your local widget was not changed.';
  }, retryUpload);

  Future<void> refresh() => _run((revision) async {
    final result = await repository.listAssets();
    if (!_current(revision)) return;
    assets = result.where((a) => a.coupleId == pairing.couple!.id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    downloadedPhoto = null;
    selectedAsset = null;
    final received = assets.where((a) => a.uploaderId != pairing.userId);
    if (received.isNotEmpty) await _download(received.first, revision);
  }, refresh);

  Future<void> download(MediaAsset asset) =>
      _run((revision) => _download(asset, revision), () => download(asset));
  Future<void> _download(MediaAsset asset, int revision) async {
    if (asset.coupleId != pairing.couple?.id) {
      throw StateError('Photo is outside this couple.');
    }
    downloadedPhoto = null;
    selectedAsset = null;
    _notify();
    final photo = await repository.downloadPhoto(asset.assetId);
    if (!_current(revision)) return;
    validateUploadPng(photo);
    selectedAsset = asset;
    downloadedPhoto = Uint8List.fromList(photo);
    status =
        'Private photo downloaded. Apply it explicitly to this device below.';
  }

  Future<void> applyDownloadedLocally() => _run((revision) async {
    final photo = downloadedPhoto;
    if (photo == null || applyLocalPhoto == null) {
      throw StateError('No downloaded photo or local widget adapter.');
    }
    _localQueue = _localQueue.then((_) async {
      if (_current(revision)) await applyLocalPhoto!(photo);
    });
    try {
      await _localQueue;
    } finally {
      _localQueue = _localQueue.catchError((Object _) {});
    }
    if (_current(revision)) {
      status = 'Updated this device’s home-screen widget only.';
    }
  }, applyDownloadedLocally);

  Future<void> retry() async {
    final action = _retry;
    if (action != null) await action();
  }

  void cancel() {
    if (_disposed) return;
    _revision++;
    busy = false;
    _pendingPhoto = null;
    pendingRequestId = null;
    _retry = null;
    error = null;
    status =
        'Stopped waiting. An already submitted upload or local widget update may still finish; refresh to check server photos.';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    pairing.removeListener(_scopeChanged);
    pairing.session.removeListener(_scopeChanged);
    super.dispose();
  }
}
