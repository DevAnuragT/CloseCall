import 'push_registration_service.dart';

/// Shares the existing installation ID without two startup consumers racing to
/// create different IDs before SharedPreferences has persisted the first one.
class SingleFlightPushDeviceIdentityStore implements PushDeviceIdentityStore {
  SingleFlightPushDeviceIdentityStore(this.store);
  final PushDeviceIdentityStore store;
  Future<String>? _identity;

  @override
  Future<String> deviceId() =>
      _identity ??= store.deviceId().catchError((Object e) {
        _identity = null;
        throw e;
      });
}
