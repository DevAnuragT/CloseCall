import 'package:shared_preferences/shared_preferences.dart';

import 'widget_consent_store.dart';

/// One record (not per-account history): switching accounts cannot resurrect
/// an old opt-in. Serialize access, including reads behind outstanding writes.
class SharedPreferencesWidgetConsentStore implements WidgetConsentStore {
  SharedPreferencesWidgetConsentStore({SharedPreferencesAsync? preferences})
    : _preferences = preferences ?? SharedPreferencesAsync();

  static const key = 'closecall.widget.deviceConsent.v1';
  final SharedPreferencesAsync _preferences;
  Future<void> _tail = Future.value();

  Future<T> _enqueue<T>(Future<T> Function() operation) {
    final result = _tail.then((_) => operation());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  @override
  Future<WidgetDeviceConsent?> read() => _enqueue(() async {
    return WidgetDeviceConsent.decode(await _preferences.getString(key));
  });

  @override
  Future<void> write(WidgetDeviceConsent? consent) => _enqueue(() async {
    if (consent == null) {
      await _preferences.remove(key);
    } else {
      await _preferences.setString(key, consent.encode());
    }
  });
}
