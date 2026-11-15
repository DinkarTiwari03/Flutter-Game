import 'package:city_builder_2040/models/app_settings.dart';

/// Persistence contract for user preferences.
///
/// See `CityRepository` for the shared contract conventions.
abstract interface class SettingsRepository {
  /// Loads the stored settings, returning defaults when nothing has been saved.
  Future<AppSettings> getSettings();

  /// Persists the full settings object (upsert).
  Future<void> saveSettings(AppSettings settings);

  /// Resets all settings to their default values.
  Future<void> resetSettings();
}
