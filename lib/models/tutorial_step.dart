/// Steps in the first-time player tutorial.
enum TutorialStep {
  /// Welcome screen — introduces the game concept.
  welcome,

  /// Instructs the player to place their first residential building.
  placeFirstBuilding,

  /// Shows how to build a road.
  buildRoad,

  /// Points to the Economy panel.
  checkEconomy,

  /// Points to the Missions panel.
  checkMissions,

  /// Tutorial complete.
  done,
}

extension TutorialStepX on TutorialStep {
  String get title {
    switch (this) {
      case TutorialStep.welcome:
        return 'Welcome to City Builder 2040!';
      case TutorialStep.placeFirstBuilding:
        return 'Place Your First Building';
      case TutorialStep.buildRoad:
        return 'Build a Road';
      case TutorialStep.checkEconomy:
        return 'Manage Your Economy';
      case TutorialStep.checkMissions:
        return 'Complete Missions';
      case TutorialStep.done:
        return 'You\'re Ready!';
    }
  }

  String get description {
    switch (this) {
      case TutorialStep.welcome:
        return 'Build a thriving city of the future. Tap the Build button '
            'to start placing buildings and grow your population.';
      case TutorialStep.placeFirstBuilding:
        return 'Open the Build panel and select a Small House. Tap a green '
            'tile on the map to place it. Each house increases housing capacity.';
      case TutorialStep.buildRoad:
        return 'Open the Roads panel and lay a road to connect your buildings. '
            'Well-connected buildings are more efficient.';
      case TutorialStep.checkEconomy:
        return 'Tap the Economy tab to see your city\'s income, expenses and '
            'resource levels. Keep your budget positive!';
      case TutorialStep.checkMissions:
        return 'Tap the Missions tab to see your goals and collect rewards. '
            'Completing missions earns XP and unlocks new buildings.';
      case TutorialStep.done:
        return 'You know the basics! Keep building, grow your population and '
            'reach new Mayor levels. Good luck, Mayor!';
    }
  }

  TutorialStep? get next {
    final values = TutorialStep.values;
    final idx = values.indexOf(this);
    if (idx < values.length - 1) return values[idx + 1];
    return null;
  }

  bool get isLast => this == TutorialStep.done;
}
