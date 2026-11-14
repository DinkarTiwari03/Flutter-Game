import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/models/app_settings.dart';

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => const AppSettings();

  void setSoundEnabled(bool value) =>
      state = state.copyWith(soundEnabled: value);

  void setMusicEnabled(bool value) =>
      state = state.copyWith(musicEnabled: value);
}

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);
