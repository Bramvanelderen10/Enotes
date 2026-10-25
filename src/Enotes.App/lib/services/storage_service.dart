import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _apiUrlKey = 'api_base_url';
  static const _usernameKey = 'notes_username';

  late final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  Future<(String, String)?> getConfig() async {
    final url = await _prefs.getString(_apiUrlKey);
    final username = await _prefs.getString(_usernameKey);
    if (url == null || url.isEmpty || username == null || username.isEmpty) {
      return null;
    }
    return (url, username);
  }

  Future<void> saveConfig(String url, String username) async {
    await _prefs.setString(_apiUrlKey, url);
    await _prefs.setString(_usernameKey, username);
  }

  Future<void> clearConfig() async {
    await _prefs.remove(_apiUrlKey);
    await _prefs.remove(_usernameKey);
  }
}
