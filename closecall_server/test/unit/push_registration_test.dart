import 'package:closecall_server/src/generated/protocol.dart';
import 'package:serverpod/serverpod.dart';
import 'package:test/test.dart';

void main() {
  test('push registration model round trips without exposing a client DTO', () {
    final value = PushDeviceRegistration(
      coupleId: UuidValue.fromString('11111111-1111-4111-8111-111111111111'),
      memberId: 7,
      deviceId: 'device',
      token: 'opaque-token',
      platform: 'android',
      appVersion: '1.0.0+1',
      updatedAt: DateTime.utc(2026, 10, 6),
    );
    final roundTrip = PushDeviceRegistration.fromJson(value.toJson());
    expect(roundTrip.deviceId, 'device');
    expect(roundTrip.token, 'opaque-token');
    expect(roundTrip.revokedAt, isNull);
  });

  test('runtime schema keeps push member couple identity constrained', () {
    final table = Protocol()
        .getTargetTableDefinitions()
        .singleWhere((table) => table.name == 'closecall_push_device_registration');
    final key = table.foreignKeys.singleWhere(
      (key) => key.constraintName == 'closecall_push_registration_same_couple_member',
    );
    expect(key.columns.toSet(), {'coupleId', 'memberId'});
    expect(key.referenceColumns.toSet(), {'coupleId', 'id'});
  });
}
