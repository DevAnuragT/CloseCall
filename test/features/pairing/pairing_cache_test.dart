import 'package:closecall/features/couple/domain/couple.dart';
import 'package:closecall/features/pairing/data/pairing_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Preferences implements SharedPreferencesAsync {
  final values = <String, String>{};

  @override
  Future<String?> getString(String key) async => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  Couple couple({List<String> members = const ['me', 'partner']}) => Couple(
    id: 'couple',
    memberIds: members,
    ownNickname: 'Me',
    partnerNickname: 'Partner',
    anniversary: DateTime.utc(2026, 10, 1),
    themeKey: 'lavender',
  );

  test('persists a complete scoped pairing and invite code', () async {
    final preferences = _Preferences();
    final cache = SharedPreferencesPairingCache(preferences: preferences);

    await cache.write('me', couple(), 'ABCD1234');
    final restored = await cache.read('me');

    expect(restored?.couple, couple());
    expect(restored?.inviteCode, 'ABCD1234');
  });

  test('ignores incomplete, wrong-scope, and corrupt snapshots', () async {
    final preferences = _Preferences();
    final cache = SharedPreferencesPairingCache(preferences: preferences);

    await cache.write('me', couple(members: const ['me']), 'INVITE');
    expect(await cache.read('me'), isNull);

    await cache.write('other', couple(), 'INVITE');
    expect(await cache.read('me'), isNull);

    preferences.values['closecall.pairing.cache.v1.me'] = '{not-json';
    expect(await cache.read('me'), isNull);
  });

  test('clear removes only the requested identity snapshot', () async {
    final preferences = _Preferences();
    final cache = SharedPreferencesPairingCache(preferences: preferences);

    await cache.write('me', couple(), null);
    await cache.write(
      'other',
      couple(members: const ['other', 'partner']),
      null,
    );
    await cache.clear('me');

    expect(await cache.read('me'), isNull);
    expect((await cache.read('other'))?.couple.id, 'couple');
  });
}
