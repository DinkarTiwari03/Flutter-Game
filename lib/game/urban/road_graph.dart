import 'dart:collection';
import 'dart:math' as math;
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/urban/compass_direction.dart';
import 'package:city_builder_2040/models/building.dart';

/// Graph representation of the city's road network.
///
/// In City Builder 2040, roads are 1x1 placed structures with `typeId == 'road'`.
/// This graph enables vehicle pathfinding, intersection detection, and
/// turn resolution.
class RoadGraph {
  RoadGraph() : _adjacency = {}, _roadTiles = {};

  final Set<GridPoint> _roadTiles;
  final Map<GridPoint, List<GridPoint>> _adjacency;

  /// Returns whether [point] contains a paved road tile.
  bool contains(GridPoint point) => _roadTiles.contains(point);

  /// All road tiles in the network.
  Set<GridPoint> get roadTiles => UnmodifiableSetView(_roadTiles);

  /// Whether the network currently contains any roads.
  bool get isEmpty => _roadTiles.isEmpty;

  /// Number of active road tiles.
  int get length => _roadTiles.length;

  /// Adjacent road tiles connected to [tile].
  List<GridPoint> neighborsOf(GridPoint tile) => _adjacency[tile] ?? const [];

  /// Rebuilds the road graph from the current list of city buildings.
  void updateFromBuildings(List<Building> buildings) {
    _roadTiles.clear();
    _adjacency.clear();

    for (final b in buildings) {
      if (b.typeId == 'road') {
        _roadTiles.add(GridPoint(b.x, b.y));
      }
    }

    // Build 4-way orthogonal adjacency (NE, NW, SE, SW)
    const deltas = [
      GridPoint(1, 0),  // SE (+col)
      GridPoint(-1, 0), // NW (-col)
      GridPoint(0, 1),  // SW (+row)
      GridPoint(0, -1), // NE (-row)
    ];

    for (final road in _roadTiles) {
      final connected = <GridPoint>[];
      for (final delta in deltas) {
        final neighbor = GridPoint(road.col + delta.col, road.row + delta.row);
        if (_roadTiles.contains(neighbor)) {
          connected.add(neighbor);
        }
      }
      _adjacency[road] = connected;
    }
  }

  /// Whether [tile] is an intersection (3 or more connected branches).
  bool isIntersection(GridPoint tile) => (_adjacency[tile]?.length ?? 0) >= 3;

  /// Whether [tile] is a dead-end road (0 or 1 connection).
  bool isDeadEnd(GridPoint tile) => (_adjacency[tile]?.length ?? 0) <= 1;

  /// Finds the shortest path of road tiles from [start] to [goal] using Breadth-First Search.
  List<GridPoint>? findPath(GridPoint start, GridPoint goal) {
    if (!_roadTiles.contains(start) || !_roadTiles.contains(goal)) return null;
    if (start == goal) return [start];

    final queue = Queue<GridPoint>()..add(start);
    final cameFrom = <GridPoint, GridPoint>{};
    final visited = <GridPoint>{start};

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (current == goal) {
        // Reconstruct path
        final path = <GridPoint>[current];
        var curr = current;
        while (curr != start) {
          curr = cameFrom[curr]!;
          path.add(curr);
        }
        return path.reversed.toList();
      }

      final neighbors = _adjacency[current] ?? const [];
      for (final next in neighbors) {
        if (!visited.contains(next)) {
          visited.add(next);
          cameFrom[next] = current;
          queue.add(next);
        }
      }
    }

    return null; // Unreachable
  }

  /// Selects the next road tile for continuous wandering vehicles.
  ///
  /// Prefers continuing forward or turning over immediate 180-degree U-turns
  /// unless reaching a dead end.
  GridPoint? pickNextRoad(
    GridPoint current,
    CompassDirection? currentHeading,
    math.Random random,
  ) {
    final neighbors = _adjacency[current];
    if (neighbors == null || neighbors.isEmpty) return null;
    if (neighbors.length == 1) return neighbors.first;

    // Filter out immediate reverse direction if alternatives exist
    if (currentHeading != null) {
      final reverseDir = currentHeading.opposite;
      final reverseTile = GridPoint(
        current.col + reverseDir.gridDelta.col,
        current.row + reverseDir.gridDelta.row,
      );

      final forwardChoices = neighbors.where((n) => n != reverseTile).toList();
      if (forwardChoices.isNotEmpty) {
        // Favor continuing in same direction if open (70% probability)
        final straightTile = GridPoint(
          current.col + currentHeading.gridDelta.col,
          current.row + currentHeading.gridDelta.row,
        );

        if (forwardChoices.contains(straightTile) && random.nextDouble() < 0.70) {
          return straightTile;
        }

        return forwardChoices[random.nextInt(forwardChoices.length)];
      }
    }

    return neighbors[random.nextInt(neighbors.length)];
  }

  /// Locates the nearest road tile to a given [point], searching outward up to [maxDistance].
  GridPoint? findNearestRoad(GridPoint point, {int maxDistance = 6}) {
    if (_roadTiles.contains(point)) return point;
    if (_roadTiles.isEmpty) return null;

    GridPoint? best;
    var bestDist = double.infinity;

    for (final road in _roadTiles) {
      final dist = (road.col - point.col).abs() + (road.row - point.row).abs();
      if (dist <= maxDistance && dist < bestDist) {
        bestDist = dist.toDouble();
        best = road;
      }
    }

    return best;
  }
}
