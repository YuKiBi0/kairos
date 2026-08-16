import '../entities/app_preferences.dart';

abstract interface class SettingsRepository {
  Stream<AppPreferences> watchPreferences();

  Future<AppPreferences> loadPreferences();

  Future<void> savePreferences(AppPreferences preferences);

  Future<String> getOrCreateDeviceId();

  Future<String?> readServiceEndpoint();

  Future<void> saveServiceEndpoint(String? endpoint);
}
