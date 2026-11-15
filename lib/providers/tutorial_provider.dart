import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/models/tutorial_step.dart';
import 'package:city_builder_2040/providers/settings_provider.dart';

/// Controls which tutorial step is currently active.
///
/// Starts idle (`null`). Triggered when founding a new city (if the player has
/// not completed it yet) or explicitly via the Settings screen.
class TutorialNotifier extends Notifier<TutorialStep?> {
  @override
  TutorialStep? build() => null;

  /// Starts the tutorial from the welcome step.
  void start() {
    state = TutorialStep.welcome;
  }

  /// Advance to the next step, or finish the tutorial.
  Future<void> advance() async {
    final current = state;
    if (current == null) return;
    final next = current.next;
    if (next == null || next.isLast) {
      state = TutorialStep.done;
      // Mark as completed in settings so it doesn't show again.
      await ref.read(settingsProvider.notifier).completeTutorial();
      state = null;
    } else {
      state = next;
    }
  }

  /// Dismiss the tutorial entirely without completing it.
  Future<void> dismiss() async {
    await ref.read(settingsProvider.notifier).completeTutorial();
    state = null;
  }
}

final tutorialProvider = NotifierProvider<TutorialNotifier, TutorialStep?>(
  TutorialNotifier.new,
);
