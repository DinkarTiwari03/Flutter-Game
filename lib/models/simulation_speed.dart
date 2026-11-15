/// Speed of the game simulation.
///
/// In Phase 2 this drives the HUD pause / speed toggles; the ticker engine that
/// advances game state uses this in future phases.
enum SimulationSpeed {
  paused('Paused', 0),
  normal('1x', 1),
  fast('2x', 2),
  superFast('3x', 3);

  const SimulationSpeed(this.label, this.multiplier);

  final String label;
  final int multiplier;

  bool get isPaused => this == paused;
}
