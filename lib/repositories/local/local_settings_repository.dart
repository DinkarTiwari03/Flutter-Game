import 'dart:convert';

import 'package:city_builder_2040/core/utils/app_exception.dart';
import 'package:city_builder_2040/models/app_settings.dart';
import 'package:city_builder_2040/repositories/local/app_database.dart';
import 'package:city_builder_2040/repositories/settings_repository.dart';

class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository(this._db);
  final AppDatabase _db;

  static const _key = 'app_settings_v1';

  @override
  Future<AppSettings> getSettings() async {
    try {
      final json = await _db.getSetting(_key);
      if (json == null) return const AppSettings();
      final map = jsonDecode(json) as Map<String, Object?>;
      return AppSettings.fromJson(map);
    } catch (e, s) {
      throw RepositoryException('Failed to load settings.', cause: e, stackTrace: s);
    }
  }

  @override
  Future<void> saveSettings(AppSettings settings) async {
    try {
      final json = jsonEncode(settings.toJson());
      await _db.putSetting(_key, json);
    } catch (e, s) {
      throw RepositoryException('Failed to save settings.', cause: e, stackTrace: s);
    }
  }

  @override
  Future<void> resetSettings() async {
    try {
      await _db.clearAllSettings();
    } catch (e, s) {
      throw RepositoryException('Failed to reset settings.', cause: e, stackTrace: s);
    }
  }
}
