import 'package:hive_flutter/hive_flutter.dart';
import 'package:city_builder_2040/core/constants/app_constants.dart';
import 'package:city_builder_2040/core/utils/app_exception.dart';

/// Thin wrapper around Hive for small key-value app preferences.
///
/// Game data (cities, buildings, resources, missions, progress) does not go
/// through this class. It is accessed via the repository interfaces in
/// `lib/repositories`.
class StorageService {
  Box<dynamic>? _settings;

  bool get isReady => _settings != null;

  Future<void> init() async {
    if (isReady) return;
    try {
      await Hive.initFlutter();
      _settings = await Hive.openBox<dynamic>(AppConstants.settingsBoxName);
    } catch (error, stack) {
      throw StorageException(
        'Could not open local storage.',
        cause: error,
        stackTrace: stack,
      );
    }
  }

  T? read<T>(String key) => _box.get(key) as T?;

  Future<void> write(String key, Object? value) => _box.put(key, value);

  Box<dynamic> get _box {
    final box = _settings;
    if (box == null) {
      throw const StorageException('Storage has not been initialised.');
    }
    return box;
  }
}
