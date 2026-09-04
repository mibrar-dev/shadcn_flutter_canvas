/// Prefs abstraction so the store stays unit-testable without plugins.
import 'package:shared_preferences/shared_preferences.dart';

/// Minimal key/value string storage port.
abstract class PrefsPort {
  Future<void> write(String key, String value);
  Future<String?> read(String key);
}

/// Production adapter backed by `shared_preferences` (web: localStorage).
class SharedPreferencesPrefs implements PrefsPort {
  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
}
