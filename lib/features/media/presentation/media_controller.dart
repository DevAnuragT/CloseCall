import 'dart:async';
import 'dart:collection';
import 'package:closecall_client/closecall_client.dart' hide Uuid;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../../../core/async/bounded_retry.dart';
import '../../pairing/presentation/pairing_controller.dart';
import '../data/media_repository.dart';
import '../data/photo_preparation.dart';

class MediaController extends ChangeNotifier {
  MediaController({
    required this.pairing,
    required this.repository,
    this.applyLocalPhoto,
    this.clearLocalPhoto,
    this.sendAsset,
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
  final Future<WidgetSendReceipt> Function(String, String)? sendAsset;
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
  MediaAsset? _pendingSendAsset;
  String? _pendingSendRequestId;
  Future<void> Function()? _retry;
  bool _retryIsRead = false;
  bool get hasExplicitRetry => _retry != null && !_retryIsRead;
  Future<void> _localQueue = Future.value();
  // Preview reads have their own lifecycle: a new upload/send command must not
  // invalidate them, and reading a picture must not steal the command's retry.
  int _photoRevision = 0;
  int _photoDownloads = 0;
  int _photoBytes = 0;
  final _photos = <String, Uint8List>{};
  final _photoErrors = <String, Object>{};
  final _photoRequests = <String, _PhotoRequest>{};
  final _photoQueue = Queue<_PhotoRequest>();

  /// Scope-private, immutable encoded PNG bytes. Reading promotes an LRU entry.
  /// At most 12 photos / 24 MiB are retained; evicted photos can be loaded again.
  Uint8List? photoFor(String assetId) {
    if (!_photoScopeCurrent) return null;
    final photo = _photos.remove(assetId);
    if (photo != null) _photos[assetId] = photo;
    return photo;
  }

  Object? photoLoadErrorFor(String assetId) =>
      _photoScopeCurrent ? _photoErrors[assetId] : null;

  bool photoLoading(String assetId) =>
      _photoScopeCurrent && _photoRequests.containsKey(assetId);

  bool get _photoScopeCurrent =>
      !_disposed && _scope != null && _scope == _currentScope;

  void _validatePhotoAsset(MediaAsset asset) {
    if (!_photoScopeCurrent ||
        asset.assetId.isEmpty ||
        asset.coupleId != pairing.couple?.id ||
        !pairing.couple!.memberIds.contains(asset.uploaderId)) {
      throw StateError('Photo is outside this couple.');
    }
  }

  /// Read-only preview request. Deduplicates by asset, runs at most two private
  /// downloads, and never changes busy, operation errors, selection or retries.
  /// Failures are available via [photoLoadErrorFor]; call again to retry.
  Future<void> loadPhoto(MediaAsset asset) {
    if (_disposed) return Future.value();
    try {
      _validatePhotoAsset(asset);
    } catch (failure) {
      if (_photoScopeCurrent) {
        _rememberPhotoError(asset.assetId, failure);
        _notify();
      }
      return Future.value();
    }
    if (photoFor(asset.assetId) != null) return Future.value();
    final existing = _photoRequests[asset.assetId];
    if (existing != null) return existing.completion.future;
    _photoErrors.remove(asset.assetId);
    final request = _PhotoRequest(asset.copyWith(), _photoRevision);
    _photoRequests[asset.assetId] = request;
    _photoQueue.add(request);
    _drainPhotoQueue();
    _notify();
    return request.completion.future;
  }

  void _rememberPhotoError(String id, Object failure) {
    _photoErrors.remove(id);
    _photoErrors[id] = failure;
    while (_photoErrors.length > 12) {
      _photoErrors.remove(_photoErrors.keys.first);
    }
  }

  void _cachePhoto(MediaAsset asset, Uint8List bytes) {
    _validatePhotoAsset(asset);
    validateUploadPng(bytes);
    final photo = Uint8List.fromList(bytes).asUnmodifiableView();
    _photoBytes -= _photos.remove(asset.assetId)?.length ?? 0;
    _photos[asset.assetId] = photo;
    _photoBytes += photo.length;
    _photoErrors.remove(asset.assetId);
    while (_photos.length > 12 || _photoBytes > 24 * 1024 * 1024) {
      _photoBytes -= _photos.remove(_photos.keys.first)!.length;
    }
  }

  bool _photoRequestCurrent(_PhotoRequest request) =>
      _photoScopeCurrent && request.revision == _photoRevision;

  void _drainPhotoQueue() {
    while (!_disposed && _photoDownloads < 2 && _photoQueue.isNotEmpty) {
      final request = _photoQueue.removeFirst();
      if (!_photoRequestCurrent(request)) continue;
      _photoDownloads++;
      unawaited(_fetchPhoto(request));
    }
  }

  Future<void> _fetchPhoto(_PhotoRequest request) async {
    try {
      _validatePhotoAsset(request.asset);
      final bytes = await retryWithBackoff(
        operation: () => repository.downloadPhoto(request.asset.assetId),
        isCurrent: () => _photoRequestCurrent(request),
        shouldRetry: _retryableReadFailure,
      );
      if (_photoRequestCurrent(request)) _cachePhoto(request.asset, bytes);
    } catch (failure) {
      if (_photoRequestCurrent(request)) {
        _rememberPhotoError(request.asset.assetId, failure);
      }
    } finally {
      _photoDownloads--;
      if (identical(_photoRequests[request.asset.assetId], request)) {
        _photoRequests.remove(request.asset.assetId);
      }
      if (!request.completion.isCompleted) request.completion.complete();
      _drainPhotoQueue();
      _notify();
    }
  }

  void _clearPhotoCache() {
    _photoRevision++;
    _photos.clear();
    _photoBytes = 0;
    _photoErrors.clear();
    _photoQueue.clear();
    for (final request in _photoRequests.values) {
      if (!request.completion.isCompleted) request.completion.complete();
    }
    _photoRequests.clear();
    // Keep physical download accounting until old transports actually finish.
  }

  bool get canShare => _currentScope != null;
  bool _retryableReadFailure(Object failure) =>
      failure is! MediaFailure &&
      failure is! FormatException &&
      !(failure is ServerpodClientHttpException &&
          failure.statusCode >= 400 &&
          failure.statusCode < 500 &&
          failure.statusCode != 408 &&
          failure.statusCode != 429);
  bool get hasPendingUpload => _pendingPhoto != null;
  bool get hasPendingSend => _pendingSendRequestId != null;
  bool get hasPendingMutation =>
      hasPendingUpload || hasPendingSend || _pendingSendAsset != null;
  String? get _currentScope =>
      pairing.userId != null &&
          pairing.hasLoadedPairing &&
          pairing.couple?.isComplete == true &&
          pairing.couple!.memberIds.contains(pairing.userId)
      ? '${pairing.userId}:${pairing.authRevision}/${pairing.couple!.id}/'
            '${(pairing.couple!.memberIds.toList()..sort()).join('/')}'
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
    _clearPhotoCache();
    assets = [];
    downloadedPhoto = null;
    selectedAsset = null;
    _pendingPhoto = null;
    _prepared = false;
    pendingRequestId = null;
    _pendingSendAsset = null;
    _pendingSendRequestId = null;
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
    Future<void> Function() retry, {
    bool resumePending = false,
    bool readOnly = false,
  }) async {
    if (_disposed || busy) return;
    if (readOnly && error != null && hasExplicitRetry) return;
    // Reads are also the reconciliation path for an upload/send whose
    // response was lost. They must be allowed to run while that mutation is
    // still held for an exact-UUID retry.
    if (!resumePending && !readOnly && (hasPendingUpload || hasPendingSend)) {
      return;
    }
    if (!canShare) {
      error = StateError('Complete pairing before sharing photos.');
      _notify();
      return;
    }
    final revision = ++_revision;
    busy = true;
    error = null;
    status = null;
    final mutationRetry = _retry;
    _retry = retry;
    _retryIsRead = readOnly;
    _notify();
    try {
      if (_current(revision)) await action(revision);
      if (_current(revision)) {
        if (readOnly && (hasPendingUpload || hasPendingSend)) {
          // Refresh is a read, not a replacement for the exact-UUID mutation
          // retry that is still waiting for explicit confirmation.
          _retry = mutationRetry ?? (hasPendingSend ? _retrySend : retryUpload);
          _retryIsRead = false;
        } else {
          _retry = null;
        }
      }
    } catch (failure) {
      if (_current(revision)) {
        if (!readOnly && _ambiguousFailure(failure)) {
          // A timeout is not a failed mutation: the server may have committed
          // it. Keep it pending until a refresh reads fresh server media.
          error = null;
          status = _pendingStatus;
        } else if (readOnly && (hasPendingUpload || hasPendingSend)) {
          // A refresh transport failure must not turn an uncertain mutation
          // into a false failure or discard the content already on screen.
          error = null;
          status = _pendingStatus;
        } else {
          error = failure;
        }
      }
    } finally {
      if (_current(revision)) {
        busy = false;
        _notify();
      }
    }
  }

  Future<void> uploadConfirmed(Uint8List photo) async {
    if (!_canStartPhoto()) return;
    // Preserve an immutable payload and UUID for retry after uncertain failures.
    _pendingPhoto = Uint8List.fromList(photo);
    _prepared = false;
    pendingRequestId = _requestId();
    await retryUpload();
  }

  bool _canStartPhoto() {
    if (busy || _disposed || hasPendingUpload || hasPendingSend) return false;
    if (canShare) return true;
    error = StateError('Complete pairing before sharing photos.');
    _notify();
    return false;
  }

  /// Upload and send are separate acknowledged stages. An uncertain send keeps
  /// its exact asset and UUID; explicit retry must never upload it a second time.
  Future<void> sendConfirmed(Uint8List photo) async {
    if (!_canStartPhoto()) return;
    _pendingPhoto = Uint8List.fromList(photo);
    _prepared = false;
    pendingRequestId = _requestId();
    _pendingSendRequestId = _requestId();
    await _retrySend();
  }

  Future<void> sendUploaded(MediaAsset asset) async {
    if (!_canStartPhoto()) return;
    try {
      _validateOwnAsset(asset);
    } catch (failure) {
      error = failure;
      status = null;
      _notify();
      return;
    }
    _pendingSendAsset = asset.copyWith();
    _pendingSendRequestId = _requestId();
    await _retrySend();
  }

  void _validateOwnAsset(MediaAsset asset) {
    if (asset.assetId.isEmpty ||
        asset.coupleId != pairing.couple?.id ||
        asset.uploaderId != pairing.userId) {
      throw StateError('Only your own photo in this couple can be sent.');
    }
  }

  Future<void> _retrySend() => _run(
    (revision) async {
      if (_pendingSendRequestId == null) return;
      if (sendAsset == null) throw StateError('Photo sending is unavailable.');
      if (_pendingSendAsset == null) {
        final uploaded = await _upload(revision);
        if (!_current(revision) || uploaded == null) return;
        _pendingSendAsset = uploaded.copyWith();
        _notify();
      }
      if (!_current(revision)) return;
      final asset = _pendingSendAsset!;
      _validateOwnAsset(asset);
      final id = _pendingSendRequestId!;
      final sender = pairing.userId!;
      final couple = pairing.couple!;
      final recipient = couple.memberIds.singleWhere(
        (member) => member != sender,
      );
      final receipt = await sendAsset!(asset.assetId, id);
      if (!_current(revision)) return;
      if (receipt.requestId != id ||
          receipt.assetId != asset.assetId ||
          receipt.coupleId != couple.id ||
          receipt.senderId != sender ||
          receipt.recipientId != recipient ||
          receipt.sendId.isEmpty ||
          receipt.version < 1) {
        throw StateError('Could not confirm the sent photo.');
      }
      _pendingSendAsset = null;
      _pendingSendRequestId = null;
      status = receipt.recipientAutoUpdateEnabled
          ? 'Sent. Delivery is waiting for your partner’s opted-in device. Active schedules take priority.'
          : 'Sent. Delivery is waiting for your partner to enable photo updates; queued until your partner allows updates. Active schedules take priority.';
    },
    _retrySend,
    resumePending: true,
  );

  Future<void> retryUpload() {
    if (hasPendingSend) return _retrySend();
    return _run(
      (revision) async {
        final result = await _upload(revision);
        if (!_current(revision) || result == null) return;
        status =
            'Uploaded privately to your couple. Your local widget was not changed.';
      },
      retryUpload,
      resumePending: true,
    );
  }

  Future<MediaAsset?> _upload(int revision) async {
    if (!_current(revision)) return null;
    if (_pendingPhoto == null || pendingRequestId == null) return null;
    final original = _pendingPhoto!;
    final id = pendingRequestId!;
    final prepared = _prepared ? original : await _prepare(original);
    if (!_current(revision)) return null;
    validateUploadPng(prepared);
    _pendingPhoto = prepared;
    _prepared = true;
    final result = await repository.uploadPhoto(prepared, id);
    if (!_current(revision)) return null;
    _validateOwnAsset(result);
    _cachePhoto(result, prepared);
    _pendingPhoto = null;
    pendingRequestId = null;
    assets = [result, ...assets.where((a) => a.assetId != result.assetId)];
    return result;
  }

  bool _ambiguousFailure(Object failure) {
    if (failure is TimeoutException ||
        failure is ServerpodClientNetworkException) {
      return true;
    }
    return failure is ServerpodClientHttpException &&
        (failure.statusCode == 408 ||
            failure.statusCode == 429 ||
            failure.statusCode >= 500);
  }

  String get _pendingStatus => _pendingSendRequestId != null
      ? 'Photo send is waiting for server confirmation. Pull down to refresh or retry the same send.'
      : 'Photo upload is waiting for server confirmation. Pull down to refresh or retry the same upload.';

  Future<void> refresh() => _run(
    (revision) async {
      final result = await retryWithBackoff(
        operation: repository.listAssets,
        isCurrent: () => _current(revision),
        shouldRetry: _retryableReadFailure,
      );
      if (!_current(revision)) return;
      final oldSelected = selectedAsset;
      final oldDownloaded = downloadedPhoto;
      assets =
          result
              .where(
                (a) =>
                    a.coupleId == pairing.couple!.id &&
                    pairing.couple!.memberIds.contains(a.uploaderId),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (oldSelected == null ||
          !assets.any((asset) => asset.assetId == oldSelected.assetId)) {
        downloadedPhoto = null;
        selectedAsset = null;
      } else {
        selectedAsset = assets.firstWhere(
          (asset) => asset.assetId == oldSelected.assetId,
        );
        downloadedPhoto = oldDownloaded;
      }
      final received = assets
          .where((asset) => asset.uploaderId != pairing.userId)
          .firstOrNull;
      // Recover failed thumbnails without evicting verified photos or replaying
      // pending uploads/sends.
      await Future.wait([
        for (final asset in assets)
          if (_photoErrors.containsKey(asset.assetId)) loadPhoto(asset),
      ]);
      if (!_current(revision)) return;
      if (!hasPendingMutation &&
          received != null &&
          selectedAsset?.assetId != received.assetId &&
          selectedAsset == null) {
        await _download(received, revision);
      }
      if (!_current(revision)) return;
      if (_current(revision) && (hasPendingUpload || hasPendingSend)) {
        // Do not download private bytes just to guess whether an ambiguous
        // mutation committed. The stable request UUID is the authority: an
        // explicit retry asks the server to return the existing row without
        // duplicating the upload or send.
        status = _pendingStatus;
      }
    },
    refresh,
    readOnly: true,
  );

  Future<void> download(MediaAsset asset) {
    if (hasPendingMutation) return Future<void>.value();
    return _run(
      (revision) => _download(asset, revision),
      () => download(asset),
      readOnly: true,
    );
  }

  Future<void> _download(MediaAsset asset, int revision) async {
    _validatePhotoAsset(asset);
    downloadedPhoto = null;
    selectedAsset = null;
    _notify();
    await loadPhoto(asset);
    if (!_current(revision)) return;
    final photo = photoFor(asset.assetId);
    if (photo == null) {
      throw photoLoadErrorFor(asset.assetId) ??
          StateError('Private photo is no longer available.');
    }
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
    _prepared = false;
    pendingRequestId = null;
    _pendingSendAsset = null;
    _pendingSendRequestId = null;
    _retry = null;
    error = null;
    status =
        'Stopped waiting. An already submitted upload, send or local widget update may still finish; refresh to check server photos.';
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _revision++;
    _clearPhotoCache();
    _pendingPhoto = null;
    _pendingSendAsset = null;
    _pendingSendRequestId = null;
    pendingRequestId = null;
    _retry = null;
    pairing.removeListener(_scopeChanged);
    pairing.session.removeListener(_scopeChanged);
    super.dispose();
  }
}

class _PhotoRequest {
  _PhotoRequest(this.asset, this.revision);
  final MediaAsset asset;
  final int revision;
  final completion = Completer<void>();
}
