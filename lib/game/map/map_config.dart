import 'package:city_builder_2040/core/constants/game_constants.dart';

/// Parameters that fully determine a generated map.
class MapConfig {
  MapConfig({required this.cols, required this.rows, this.seed = 0})
    : assert(
        cols >= GameConstants.minMapSize && cols <= GameConstants.maxMapSize,
      ),
      assert(
        rows >= GameConstants.minMapSize && rows <= GameConstants.maxMapSize,
      );

  final int cols;
  final int rows;
  final int seed;
}

/// Map sizes offered when starting a new game.
enum MapSizePreset {
  small('Small', 48),
  medium('Medium', 64),
  large('Large', 96),
  huge('Huge', 128);

  const MapSizePreset(this.label, this.size);

  final String label;

  /// Width and height in tiles (maps are square).
  final int size;

  String get dimensions => '$size x $size';

  /// The preset matching [size], or [medium] when none does.
  static MapSizePreset fromSize(int size) {
    return values.firstWhere((p) => p.size == size, orElse: () => medium);
  }
}
