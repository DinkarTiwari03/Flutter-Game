import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/map/tile_type.dart';

/// Read-only description of one tile, for the inspection panel.
class TileInfo {
  const TileInfo({
    required this.point,
    required this.type,
    required this.decoration,
    required this.roadLinks,
  });

  /// Describes the tile at [point]. The point must be inside [map].
  factory TileInfo.of(GameMap map, GridPoint point) {
    final c = point.col;
    final r = point.row;

    bool isRoad(int nc, int nr) =>
        map.inBounds(nc, nr) && map.typeAt(nc, nr) == TileType.road;

    final links = <String>[
      if (isRoad(c, r - 1)) 'North-east',
      if (isRoad(c + 1, r)) 'South-east',
      if (isRoad(c, r + 1)) 'South-west',
      if (isRoad(c - 1, r)) 'North-west',
    ];

    return TileInfo(
      point: point,
      type: map.typeAt(c, r),
      decoration: map.decorationAt(c, r),
      roadLinks: links,
    );
  }

  final GridPoint point;
  final TileType type;
  final TileDecoration decoration;

  /// Directions in which this tile connects to another road.
  final List<String> roadLinks;

  bool get isRoad => type == TileType.road;

  String get title => type.label;

  String get coordinates => '${point.col}, ${point.row}';

  /// True when something stands on the tile that must be cleared before
  /// building.
  bool get hasObstacle => !decoration.isNone;

  String get buildStatus {
    if (!type.isBuildable) return 'Not buildable';
    return hasObstacle ? 'Buildable after clearing' : 'Buildable';
  }

  /// Label/value pairs for the panel.
  List<(String, String)> get details {
    return [
      ('Position', coordinates),
      ('Terrain', type.label),
      if (isRoad)
        ('Connections', roadLinks.isEmpty ? 'None' : roadLinks.join(', '))
      else
        ('Object', decoration.isNone ? 'None' : decoration.label),
      ('Status', isRoad ? 'In use' : buildStatus),
    ];
  }
}
