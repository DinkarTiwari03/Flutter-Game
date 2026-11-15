import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/models/tutorial_step.dart';

void main() {
  group('TutorialStep Model', () {
    test('All steps have titles and descriptions', () {
      for (final step in TutorialStep.values) {
        expect(step.title, isNotEmpty);
        expect(step.description, isNotEmpty);
      }
    });

    test('Steps sequence correctly from welcome to done', () {
      var current = TutorialStep.welcome;
      final sequence = <TutorialStep>[current];

      while (current.next != null) {
        current = current.next!;
        sequence.add(current);
      }

      expect(sequence, [
        TutorialStep.welcome,
        TutorialStep.placeFirstBuilding,
        TutorialStep.buildRoad,
        TutorialStep.checkEconomy,
        TutorialStep.checkMissions,
        TutorialStep.done,
      ]);

      expect(TutorialStep.done.isLast, isTrue);
      expect(TutorialStep.welcome.isLast, isFalse);
    });
  });
}
