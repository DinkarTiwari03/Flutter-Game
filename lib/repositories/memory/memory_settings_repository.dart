import 'package:city_builder_2040/models/app_settings.dart';
import 'package:city_builder_2040/repositories/settings_repository.dart';

/// In-memory implementation of [SettingsRepository] for tests and fallback.
class MemorySettingsRepository implements SettingsRepository {
  MemorySettingsRepository([AppSettings? initial])
      : _settings = initial ?? const AppSettings();

  AppSettings _settings;

  @override
  Future<AppSettings> getSettings() async => _settings;

  @override
  Future<void> saveSettings(AppSettings settings) async {
    _settings = settings;
  }

  @override
  Future<void> resetSettings() async {
    _settings = const AppSettings();
  }
}
