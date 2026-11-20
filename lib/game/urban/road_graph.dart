import 'dart:collection';
import 'dart:math' as math;
import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/map/tile_type.dart';
import 'package:city_builder_2040/game/urban/compass_direction.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/traffic/traffic_models.dart';

/// Graph representation of the city's road network, traffic signals,
/// and congestion-aware routing engine.
class RoadGraph {
  RoadGraph()
      : _adjacency = {},
        _roadTiles = {},
        _roadLevels = {},
        _signals = {},
        _busStops = {},
        _busStations = {};

  final Set<GridPoint> _roadTiles;
  final Map<GridPoint, List<GridPoint>> _adjacency;
  final Map<GridPoint, int> _roadLevels;
  final Map<GridPoint, TrafficSignal> _signals;
  final Set<GridPoint> _busStops;
  final Set<GridPoint> _busStations;
  final Set<GridPoint> _blockedTiles = {};

  /// Dynamically blocked road tiles (e.g. due to earthquake, flood, storm, or fire).
  Set<GridPoint> get blockedTiles => UnmodifiableSetView(_blockedTiles);

  /// Sets tiles that are currently impassable due to disasters or construction.
  void setBlockedTiles(Set<GridPoint> blocked) {
    _blockedTiles.clear();
    _blockedTiles.addAll(blocked);
  }

  /// Whether [tile] is currently blocked.
  bool isBlocked(GridPoint tile) => _blockedTiles.contains(tile);

  /// Returns whether [point] contains a paved road tile.
  bool contains(GridPoint point) => _roadTiles.contains(point);

  /// All road tiles in the network.
  Set<GridPoint> get roadTiles => UnmodifiableSetView(_roadTiles);

  /// All registered bus stops.
  Set<GridPoint> get busStops => UnmodifiableSetView(_busStops);

  /// All registered bus stations.
  Set<GridPoint> get busStations => UnmodifiableSetView(_busStations);

  /// All active traffic signals.
  Map<GridPoint, TrafficSignal> get signals => UnmodifiableMapView(_signals);

  /// Whether the network currently contains any roads.
  bool get isEmpty => _roadTiles.isEmpty;

  /// Number of active road tiles.
  int get length => _roadTiles.length;

  /// Adjacent road tiles connected to [tile] (excludes disaster-blocked tiles).
  List<GridPoint> neighborsOf(GridPoint tile) {
    final list = _adjacency[tile] ?? const [];
    if (_blockedTiles.isEmpty) return list;
    return list.where((n) => !_blockedTiles.contains(n)).toList();
  }

  /// Road level (1 to 4) at [tile].
  int roadLevelAt(GridPoint tile) => _roadLevels[tile] ?? 1;

  /// Road tier configuration at [tile].
  RoadTier tierAt(GridPoint tile) =>
      RoadTier.fromLevel(roadLevelAt(tile));

  /// Maximum vehicle capacity for [tile].
  int capacityAt(GridPoint tile) => tierAt(tile).capacity;

  /// Speed limit in world pixels per second for [tile].
  double speedLimitAt(GridPoint tile) => tierAt(tile).speedLimit;

  /// Signal controlling [tile], or null if unsignalized.
  TrafficSignal? signalAt(GridPoint tile) => _signals[tile];

  /// Advances all active traffic light timers by [dt].
  void updateSignals(double dt) {
    for (final signal in _signals.values) {
      signal.update(dt);
    }
  }

  /// Rebuilds the road graph from current city buildings and [map].
  void updateFromBuildings(List<Building> buildings, {GameMap? map}) {
    _roadTiles.clear();
    _adjacency.clear();
    _roadLevels.clear();
    _busStops.clear();
    _busStations.clear();

    if (map != null) {
      for (var r = 0; r < map.rows; r++) {
        for (var c = 0; c < map.cols; c++) {
          if (map.typeAt(c, r) == TileType.road) {
            final pt = GridPoint(c, r);
            _roadTiles.add(pt);
            _roadLevels[pt] = 1;
          }
        }
      }
    }

    for (final b in buildings) {
      if (b.typeId == 'road') {
        final pt = GridPoint(b.x, b.y);
        _roadTiles.add(pt);
        _roadLevels[pt] = b.level.clamp(1, 4);
      } else if (b.typeId == 'bus_stop') {
        _busStops.add(GridPoint(b.x, b.y));
      } else if (b.typeId == 'bus_station') {
        // bus_station is a 2×2 building; hardcode dimensions to avoid
        // importing BuildingDefinition into the graph layer.
        const w = 2;
        const h = 2;
        for (var dx = 0; dx < w; dx++) {
          for (var dy = 0; dy < h; dy++) {
            _busStations.add(GridPoint(b.x + dx, b.y + dy));
          }
        }
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

    // Synchronize traffic signals at intersections (3+ branches or 4-way)
    final existingSignals = Map<GridPoint, TrafficSignal>.from(_signals);
    _signals.clear();

    for (final road in _roadTiles) {
      if (isIntersection(road)) {
        final existing = existingSignals[road];
        if (existing != null) {
          _signals[road] = existing;
        } else {
          // Stagger starting phase to avoid synchronized grid shifts
          final initialPhase = road.col % 2 == 0
              ? SignalState.horizontalGreen
              : SignalState.verticalGreen;
          _signals[road] = TrafficSignal(
            tile: road,
            state: initialPhase,
            timer: (road.row % 3) * 1.5,
          );
        }
      }
    }
  }

  /// Whether [tile] is an intersection (3 or more connected branches).
  bool isIntersection(GridPoint tile) => (_adjacency[tile]?.length ?? 0) >= 3;

  /// Whether [tile] is a dead-end road (0 or 1 connection).
  bool isDeadEnd(GridPoint tile) => (_adjacency[tile]?.length ?? 0) <= 1;

  /// Standard shortest-path BFS algorithm.
  List<GridPoint>? findPath(GridPoint start, GridPoint goal) {
    if (!_roadTiles.contains(start) || !_roadTiles.contains(goal)) return null;
    if (start == goal) return [start];

    final queue = Queue<GridPoint>()..add(start);
    final cameFrom = <GridPoint, GridPoint>{};
    final visited = <GridPoint>{start};

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (current == goal) {
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

    return null;
  }

  /// Advanced Congestion-Aware A* pathfinding.
  ///
  /// Incorporates:
  /// - Base travel distance
  /// - Real-time congestion load penalty (heavy / gridlock penalties)
  /// - Road capacity discounts (Boulevards and Expressways are favored)
  /// - Avoidance of [avoidTile] (used when rerouting around blocked roads).
  List<GridPoint>? findCongestionAwarePath({
    required GridPoint start,
    required GridPoint goal,
    Map<GridPoint, double> congestionLoads = const {},
    GridPoint? avoidTile,
  }) {
    if (!_roadTiles.contains(start) || !_roadTiles.contains(goal)) return null;
    if (start == goal) return [start];

    // Priority queue simulation via sorted map / list
    final openSet = <GridPoint>{start};
    final cameFrom = <GridPoint, GridPoint>{};

    final gScore = <GridPoint, double>{start: 0.0};
    final fScore = <GridPoint, double>{
      start: _heuristic(start, goal),
    };

    while (openSet.isNotEmpty) {
      // Pick node in openSet with lowest fScore
      GridPoint current = openSet.first;
      var lowestF = fScore[current] ?? double.infinity;
      for (final node in openSet) {
        final score = fScore[node] ?? double.infinity;
        if (score < lowestF) {
          lowestF = score;
          current = node;
        }
      }

      if (current == goal) {
        final path = <GridPoint>[current];
        var curr = current;
        while (curr != start) {
          curr = cameFrom[curr]!;
          path.add(curr);
        }
        return path.reversed.toList();
      }

      openSet.remove(current);
      final neighbors = _adjacency[current] ?? const [];

      for (final neighbor in neighbors) {
        if (neighbor == avoidTile && neighbor != goal) continue;
        if (_blockedTiles.contains(neighbor) && neighbor != goal) continue;

        // Base traversal cost
        var stepCost = 1.0;

        // Road tier bonus (higher capacity road = faster flow = lower cost)
        final tier = tierAt(neighbor);
        stepCost *= (1.2 / tier.level);

        // Congestion penalty
        final load = congestionLoads[neighbor] ?? 0.0;
        if (load >= 1.0) {
          // Gridlocked: heavily penalize so vehicle takes bypass roads
          stepCost += 8.0 * load;
        } else if (load >= 0.70) {
          stepCost += 3.5 * load;
        } else if (load >= 0.38) {
          stepCost += 1.2 * load;
        }

        final tentativeG = (gScore[current] ?? double.infinity) + stepCost;

        if (tentativeG < (gScore[neighbor] ?? double.infinity)) {
          cameFrom[neighbor] = current;
          gScore[neighbor] = tentativeG;
          fScore[neighbor] = tentativeG + _heuristic(neighbor, goal);
          openSet.add(neighbor);
        }
      }
    }

    // Fall back to standard BFS if congestion pathfinding fails to reach goal
    return findPath(start, goal);
  }

  static double _heuristic(GridPoint a, GridPoint b) {
    return (a.col - b.col).abs().toDouble() + (a.row - b.row).abs().toDouble();
  }

  /// Selects the next road tile for continuous roaming vehicles.
  GridPoint? pickNextRoad(
    GridPoint current,
    CompassDirection? currentHeading,
    math.Random random, {
    Map<GridPoint, double>? congestionLoads,
  }) {
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
        // If congestion map provided, prefer the least congested branch
        if (congestionLoads != null && congestionLoads.isNotEmpty) {
          forwardChoices.sort((a, b) => (congestionLoads[a] ?? 0.0)
              .compareTo(congestionLoads[b] ?? 0.0));
          if (random.nextDouble() < 0.75) {
            return forwardChoices.first;
          }
        }

        final straightTile = GridPoint(
          current.col + currentHeading.gridDelta.col,
          current.row + currentHeading.gridDelta.row,
        );

        if (forwardChoices.contains(straightTile) && random.nextDouble() < 0.65) {
          return straightTile;
        }

        return forwardChoices[random.nextInt(forwardChoices.length)];
      }
    }

    return neighbors[random.nextInt(neighbors.length)];
  }

  /// Locates the nearest road tile to [point], searching outward up to [maxDistance].
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
