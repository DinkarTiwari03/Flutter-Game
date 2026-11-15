/// Tunable values for the game world, map and camera.
abstract final class GameConstants {
  // Starting city stats (placeholders until the simulation exists).
  static const startingCoins = 25000;
  static const startingHappiness = 75;

  // Isometric tile size. A 2:1 ratio gives the classic diamond tile.
  static const tileWidth = 64.0;
  static const tileHeight = 32.0;

  // Map dimensions accepted by the generator.
  static const minMapSize = 16;
  static const maxMapSize = 256;

  // Rendering: tiles are cached as pictures in square chunks of this size.
  static const chunkSize = 16;
  static const gridMinZoom = 0.8;

  // Camera.
  static const minZoom = 0.3;
  static const maxZoom = 2.5;
  static const initialZoom = 1.0;
  static const zoomStep = 1.25;
  static const keyboardPanStep = 140.0;
  static const boundaryMargin = 192.0;

  // Input.
  static const touchTapSlop = 10.0;
  static const mouseTapSlop = 4.0;
  static const wheelZoomSensitivity = 0.0012;
  static const minFlingSpeed = 250.0;
}
