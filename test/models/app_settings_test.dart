import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/models/app_settings.dart';

void main() {
  group('AppSettings Model', () {
    test('Default values are sensible', () {
      const s = AppSettings();
      expect(s.soundEnabled, isTrue);
      expect(s.musicEnabled, isTrue);
      expect(s.masterVolume, 1.0);
      expect(s.simulationSpeed, 1);
      expect(s.showGrid, isTrue);
      expect(s.tutorialCompleted, isFalse);
    });

    test('Serialization toJson and fromJson round-trips correctly', () {
      const original = AppSettings(
        soundEnabled: false,
        musicEnabled: false,
        masterVolume: 0.5,
        simulationSpeed: 3,
        showGrid: false,
        tutorialCompleted: true,
      );

      final json = original.toJson();
      final restored = AppSettings.fromJson(json);

      expect(restored.soundEnabled, isFalse);
      expect(restored.musicEnabled, isFalse);
      expect(restored.masterVolume, 0.5);
      expect(restored.simulationSpeed, 3);
      expect(restored.showGrid, isFalse);
      expect(restored.tutorialCompleted, isTrue);
    });

    test('copyWith updates specified fields only', () {
      const original = AppSettings();
      final updated = original.copyWith(
        soundEnabled: false,
        simulationSpeed: 2,
      );

      expect(updated.soundEnabled, isFalse);
      expect(updated.simulationSpeed, 2);
      expect(updated.musicEnabled, isTrue);
      expect(updated.showGrid, isTrue);
    });
  });
}
