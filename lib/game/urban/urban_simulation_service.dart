import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/urban/compass_direction.dart';
import 'package:city_builder_2040/game/urban/pedestrian.dart';
import 'package:city_builder_2040/game/urban/road_graph.dart';
import 'package:city_builder_2040/game/urban/vehicle.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/simulation_clock.dart';
import 'package:city_builder_2040/models/traffic/traffic_models.dart';

// ─── Internal building activity record ────────────────────────────────────────

/// Tracks the urban activity spawned by a single placed building.
class _BuildingActivity {
  _BuildingActivity({
    required this.buildingId,
    required this.category,
    required this.nearestRoad,
  });

  final String buildingId;
  final BuildingCategory category;
  final GridPoint nearestRoad;

  final Set<String> spawnedVehicleIds = {};
  final Set<String> spawnedPedestrianIds = {};

  int get spawnedCount =>
      spawnedVehicleIds.length + spawnedPedestrianIds.length;
}

// ─── Staggered spawn job ───────────────────────────────────────────────────────

/// A deferred spawn action queued by [UrbanSimulationService.notifyBuildingPlaced].
class _PendingSpawn {
  _PendingSpawn({
    required this.delay,
    required this.action,
  });

  double delay;
  final void Function() action;
}

// ─── Main service ─────────────────────────────────────────────────────────────

/// Centralized simulation service managing dynamic vehicles, pedestrians,
/// and the Phase 1 Advanced Traffic Transportation System.
class UrbanSimulationService extends ChangeNotifier {
  UrbanSimulationService({
    this.maxVehicles = 45,
    this.maxPedestrians = 40,
    math.Random? random,
  }) : _random = random ?? math.Random();

  int maxVehicles;
  int maxPedestrians;
  final math.Random _random;

  final RoadGraph _roadGraph = RoadGraph();
  RoadGraph get roadGraph => _roadGraph;

  /// Updates dynamically blocked road tiles (e.g. from earthquakes, floods, or storms).
  void updateDisasterBlockedRoads(Set<GridPoint> blocked) =>
      _roadGraph.setBlockedTiles(blocked);

  final List<Vehicle> _vehicles = [];
  final List<Pedestrian> _pedestrians = [];

  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);
  List<Pedestrian> get pedestrians => List.unmodifiable(_pedestrians);

  int _nextVehicleId = 1;
  int _nextPedestrianId = 1;

  double _spawnTimer = 0.0;
  double _trafficAnalysisTimer = 0.0;
  int _lastBuildingCountHash = -1;

  /// Real-time traffic metrics and analytics.
  TrafficMetrics _trafficMetrics = TrafficMetrics.empty();
  TrafficMetrics get trafficMetrics => _trafficMetrics;

  /// Per-tile vehicle congestion cache for pathfinding lookups.
  final Map<GridPoint, double> _congestionMap = {};

  /// Per-building activity registry (key = building.id).
  final Map<String, _BuildingActivity> _buildingActivities = {};

  /// Staggered spawn jobs waiting to fire (drained in [update]).
  final List<_PendingSpawn> _pendingSpawns = [];

  // ── Road-graph sync ────────────────────────────────────────────────────────

  /// Updates the road network and prunes entities on deleted roads.
  void syncBuildings(List<Building> buildings, {GameMap? map}) {
    final currentHash = Object.hash(
      buildings.length,
      buildings.where((b) => b.typeId == 'road').length,
      map?.tileCount ?? 0,
    );

    if (currentHash != _lastBuildingCountHash) {
      _lastBuildingCountHash = currentHash;
      _roadGraph.updateFromBuildings(buildings, map: map);

      // Remove vehicles that were on demolished roads
      _vehicles.removeWhere((v) => !_roadGraph.contains(v.currentTile));
      _pedestrians.removeWhere((p) => !_roadGraph.contains(p.currentTile));
    }
  }

  // ── Immediate building-event API ───────────────────────────────────────────

  void notifyBuildingPlaced(Building building) {
    if (_roadGraph.isEmpty) return;

    final def = BuildingRegistry.get(building.typeId);
    if (def == null) return;
    if (def.isRoad) return;

    final buildingPos = GridPoint(building.x, building.y);
    final nearestRoad = _roadGraph.findNearestRoad(buildingPos);
    if (nearestRoad == null) return;

    final activity = _BuildingActivity(
      buildingId: building.id,
      category: def.category,
      nearestRoad: nearestRoad,
    );
    _buildingActivities[building.id] = activity;

    _scheduleBuildingActivity(building, def, activity);
  }

  void notifyBuildingDemolished(String buildingId) {
    _buildingActivities.remove(buildingId);
  }

  // ── Staggered burst scheduling ─────────────────────────────────────────────

  void _scheduleBuildingActivity(
    Building building,
    BuildingDefinition def,
    _BuildingActivity activity,
  ) {
    final road = activity.nearestRoad;

    switch (def.category) {
      case BuildingCategory.residential:
        final citizenCount = 2 + _random.nextInt(2);
        for (var i = 0; i < citizenCount; i++) {
          _enqueue(
            delay: i * 0.8 + _random.nextDouble() * 0.4,
            action: () => _trySpawnPedestrian(road, PedestrianType.citizen, activity),
          );
        }
        _enqueue(
          delay: 1.2,
          action: () => _trySpawnVehicle(road, VehicleType.sedan, activity),
        );
      case BuildingCategory.commercial:
        _enqueue(
          delay: 0.5,
          action: () => _trySpawnVehicle(road, VehicleType.delivery, activity),
        );
        _enqueue(
          delay: 1.8,
          action: () => _trySpawnVehicle(road, VehicleType.taxi, activity),
        );
      case BuildingCategory.industrial:
        _enqueue(
          delay: 0.8,
          action: () => _trySpawnVehicle(road, VehicleType.truckCargo, activity),
        );
      case BuildingCategory.publicServices:
        if (def.id == 'hospital') {
          _enqueue(
            delay: 1.0,
            action: () => _trySpawnVehicle(road, VehicleType.ambulance, activity),
          );
        } else if (def.id == 'police_station') {
          _enqueue(
            delay: 1.0,
            action: () => _trySpawnVehicle(road, VehicleType.police, activity),
          );
        } else if (def.id == 'fire_station') {
          _enqueue(
            delay: 1.0,
            action: () => _trySpawnVehicle(road, VehicleType.firetruck, activity),
          );
        } else if (def.id == 'bus_station') {
          _enqueue(
            delay: 0.5,
            action: () => _trySpawnVehicle(road, VehicleType.bus, activity),
          );
        }
      case BuildingCategory.infrastructure:
        if (def.id == 'bus_stop') {
          _enqueue(
            delay: 1.0,
            action: () => _trySpawnVehicle(road, VehicleType.bus, activity),
          );
        }
      case BuildingCategory.environment:
        _enqueue(
          delay: 0.5,
          action: () => _trySpawnPedestrian(road, PedestrianType.parkVisitor, activity),
        );
    }
  }

  void _enqueue({required double delay, required void Function() action}) {
    _pendingSpawns.add(_PendingSpawn(delay: delay, action: action));
  }

  void _trySpawnVehicle(
    GridPoint road,
    VehicleType type,
    _BuildingActivity? activity,
  ) {
    if (_vehicles.length >= maxVehicles) return;
    final neighbors = _roadGraph.neighborsOf(road);
    if (neighbors.isEmpty) return;

    final targetRoad = neighbors[_random.nextInt(neighbors.length)];
    final heading = CompassDirection.fromGridDelta(road, targetRoad) ??
        CompassDirection.se;

    final id = 'veh_${_nextVehicleId++}';
    final vehicle = Vehicle(
      id: id,
      type: type,
      currentTile: road,
      nextTile: targetRoad,
      heading: heading,
      originBuildingId: activity?.buildingId,
    );

    _vehicles.add(vehicle);
    activity?.spawnedVehicleIds.add(id);
  }

  void _trySpawnPedestrian(
    GridPoint road,
    PedestrianType type,
    _BuildingActivity? activity,
  ) {
    if (_pedestrians.length >= maxPedestrians) return;
    final neighbors = _roadGraph.neighborsOf(road);
    if (neighbors.isEmpty) return;

    final targetRoad = neighbors[_random.nextInt(neighbors.length)];
    final heading = CompassDirection.fromGridDelta(road, targetRoad) ??
        CompassDirection.se;

    final id = 'ped_${_nextPedestrianId++}';
    final ped = Pedestrian(
      id: id,
      type: type,
      currentTile: road,
      nextTile: targetRoad,
      heading: heading,
      sidewalkOffset: _random.nextBool() ? 10.5 : -10.5,
    );

    _pedestrians.add(ped);
    activity?.spawnedPedestrianIds.add(id);
  }

  // ── Main update loop ───────────────────────────────────────────────────────

  void update({
    required double dt,
    required List<Building> buildings,
    required SimulationClock clock,
    int population = 100,
    int happiness = 75,
    GameMap? map,
    Set<GridPoint>? disasterBlockedRoads,
  }) {
    if (disasterBlockedRoads != null) {
      _roadGraph.setBlockedTiles(disasterBlockedRoads);
    }
    syncBuildings(buildings, map: map);

    if (_roadGraph.isEmpty) {
      if (_vehicles.isNotEmpty || _pedestrians.isNotEmpty) {
        _vehicles.clear();
        _pedestrians.clear();
        _trafficMetrics = TrafficMetrics.empty();
        notifyListeners();
      }
      return;
    }

    _drainPendingSpawns(dt);

    // 1. Advance traffic light signals at intersections
    _roadGraph.updateSignals(dt);

    // 2. Update vehicle movement, queues, anti-collision, and route steps
    _updateVehicles(dt, buildings);

    // 3. Update pedestrian stride cycles and sidewalk movement
    _updatePedestrians(dt);

    // 4. Periodic background traffic generation influenced by clock and zones
    _spawnTimer += dt;
    if (_spawnTimer >= 0.75) {
      _spawnTimer = 0.0;
      _attemptSpawns(
        buildings: buildings,
        clock: clock,
        population: population,
        happiness: happiness,
      );
    }

    // 5. Periodic traffic congestion analytics (runs every ~1.0 second)
    _trafficAnalysisTimer += dt;
    if (_trafficAnalysisTimer >= 1.0) {
      _trafficAnalysisTimer = 0.0;
      _analyzeTraffic(buildings);
    }

    notifyListeners();
  }

  void _drainPendingSpawns(double dt) {
    if (_pendingSpawns.isEmpty) return;

    for (final spawn in _pendingSpawns) {
      spawn.delay -= dt;
    }

    _pendingSpawns.removeWhere((spawn) {
      if (spawn.delay <= 0.0) {
        spawn.action();
        return true;
      }
      return false;
    });
  }

  // ── Vehicle update & Advanced traffic physics ──────────────────────────────

  void _updateVehicles(double dt, List<Building> buildings) {
    for (var i = 0; i < _vehicles.length; i++) {
      final v = _vehicles[i];
      if (v.isDespawned) continue;

      // 1. Traffic signal and intersection clearance check
      _checkIntersectionSignal(v);

      // 2. Safe following distance and anti-stacking queue check
      _checkVehicleSpacingAndQueues(v);

      // 3. Public bus stops
      if (v.isBus && _roadGraph.busStops.contains(v.currentTile) && v.waitTimer <= 0) {
        if (_random.nextDouble() < 0.20 && v.progress < 0.15) {
          v.waitTimer = 1.6; // Boarding/alighting passengers
          v.passengerCount = (v.passengerCount + 4 + _random.nextInt(6)).clamp(0, 36);
        }
      }

      // 4. Move vehicle along road segment
      v.updateMovement(dt);

      // 5. Tile transition / arrival at next tile
      if (v.progress >= 1.0) {
        _handleVehicleArrival(v, buildings);
      }

      v.ageTicks++;
      // Natural lifetime despawn after roaming for ~80-100 seconds
      if (v.ageTicks > 5500 && _random.nextDouble() < 0.06) {
        v.isDespawned = true;
      }
    }

    _vehicles.removeWhere((v) => v.isDespawned);
  }

  void _checkIntersectionSignal(Vehicle v) {
    if (v.isEmergency) return; // Emergency vehicles with sirens have right of way

    // Approaching intersection near end of segment
    if (v.progress >= 0.72) {
      final signal = _roadGraph.signalAt(v.nextTile);
      if (signal != null) {
        final isEastWest = (v.heading == CompassDirection.se || v.heading == CompassDirection.nw);
        if (!signal.canPass(isEastWest: isEastWest)) {
          // Red light: stop before entering intersection
          v.isBlocked = true;
          return;
        }
      }
    }
  }

  void _checkVehicleSpacingAndQueues(Vehicle v) {
    var mustHalt = false;
    var mustSlowDown = false;

    // Road tier speed limit
    final speedLimit = _roadGraph.speedLimitAt(v.currentTile);
    final load = _congestionMap[v.currentTile] ?? 0.0;
    v.localCondition = TrafficCondition.fromLoadRatio(load);

    // Effective cruising target speed based on local road condition
    var target = speedLimit * v.localCondition.speedMultiplier;
    if (v.isEmergency) target = math.max(target, 60.0);

    for (final other in _vehicles) {
      if (identical(v, other) || other.isDespawned) continue;

      final dist = (other.worldPos - v.worldPos).distance;

      // Yield to nearby sirens
      if (!v.isEmergency && other.isEmergency && dist < 48.0) {
        mustSlowDown = true;
        target = math.min(target, 18.0);
      }

      // Proximity check in same traveling direction
      if (dist < 32.0) {
        final toOther = other.worldPos - v.worldPos;
        final headingDot = toOther.dx * v.heading.gridDelta.col +
            toOther.dy * v.heading.gridDelta.row;

        if (headingDot > 0) {
          if (dist < 16.0) {
            // Unrealistic stacking prevention: full stop
            mustHalt = true;
            break;
          } else {
            // Smoothly brake to match lead vehicle
            mustSlowDown = true;
            target = math.min(target, other.currentSpeed * 0.85);
          }
        }
      }
    }

    if (mustHalt) {
      v.isBlocked = true;
      v.currentSpeed = 0.0;
    } else {
      v.isBlocked = false;
      if (mustSlowDown) {
        v.currentSpeed = math.max(8.0, target);
      } else {
        // Accelerate smoothly to target speed
        v.currentSpeed = math.min(target, v.currentSpeed + 28.0 * 0.016);
      }
    }
  }

  void _handleVehicleArrival(Vehicle v, List<Building> buildings) {
    // If vehicle has a designated route
    if (v.hasActiveRoute) {
      v.pathIndex++;
      if (v.pathIndex < v.path.length) {
        final nextWaypoint = v.path[v.pathIndex];
        // Dynamic rerouting: if waypoint is gridlocked, try bypass path
        final wpLoad = _congestionMap[nextWaypoint] ?? 0.0;
        final isRoadBlocked = _roadGraph.isBlocked(nextWaypoint);
        if ((wpLoad >= 1.0 || isRoadBlocked) && _random.nextDouble() < 0.85) {
          final bypassPath = _roadGraph.findCongestionAwarePath(
            start: v.nextTile,
            goal: v.path.last,
            congestionLoads: _congestionMap,
            avoidTile: nextWaypoint,
          );
          if (bypassPath != null && bypassPath.length >= 2) {
            v.assignRoute(bypassPath.sublist(1));
            v.advanceTo(v.path.first);
            return;
          }
        }

        v.advanceTo(nextWaypoint);
        return;
      } else {
        // Reached destination
        if (v.destinationBuildingId != null && !v.isReturning && _random.nextDouble() < 0.40) {
          // Return trip home
          v.isReturning = true;
          final returnPath = _roadGraph.findPath(v.nextTile, v.currentTile);
          if (returnPath != null && returnPath.length >= 2) {
            v.assignRoute(returnPath.sublist(1));
            v.advanceTo(v.path.first);
            return;
          }
        }
        v.isDespawned = true;
        return;
      }
    }

    // Wandering vehicle: pick next connected road
    final nextStep = _roadGraph.pickNextRoad(
      v.nextTile,
      v.heading,
      _random,
      congestionLoads: _congestionMap,
    );

    if (nextStep != null && nextStep != v.nextTile) {
      v.advanceTo(nextStep);
      // Yield at unsignalized busy intersections
      if (_roadGraph.isIntersection(v.currentTile) &&
          _roadGraph.signalAt(v.currentTile) == null &&
          _random.nextDouble() < 0.30) {
        v.waitTimer = 0.5 + _random.nextDouble() * 0.6;
      }
    } else {
      // Dead-end: turn around or park
      if (_random.nextDouble() < 0.5) {
        v.advanceTo(v.currentTile);
      } else {
        v.isDespawned = true;
      }
    }
  }

  // ── Pedestrian update ──────────────────────────────────────────────────────

  void _updatePedestrians(double dt) {
    for (var i = 0; i < _pedestrians.length; i++) {
      final p = _pedestrians[i];
      if (p.isDespawned) continue;

      p.updateMovement(dt);

      if (p.progress >= 1.0) {
        final nextStep = _roadGraph.pickNextRoad(p.nextTile, p.heading, _random);
        if (nextStep != null && nextStep != p.nextTile) {
          p.advanceTo(nextStep);
          if (_random.nextDouble() < 0.12) {
            p.idleTimer = 1.0 + _random.nextDouble() * 2.5;
          }
        } else {
          p.isEntering = true;
        }
      }

      p.ageTicks++;
      if (p.ageTicks > 3500 && _random.nextDouble() < 0.08) {
        p.isEntering = true;
      }
    }

    _pedestrians.removeWhere((p) => p.isDespawned);
  }

  // ── Dynamic traffic demand & spawning ──────────────────────────────────────

  void _attemptSpawns({
    required List<Building> buildings,
    required SimulationClock clock,
    required int population,
    required int happiness,
  }) {
    if (_roadGraph.isEmpty) return;

    final resBuildings = <Building>[];
    final comBuildings = <Building>[];
    final indBuildings = <Building>[];
    final civicBuildings = <Building>[];

    for (final b in buildings) {
      if (b.typeId == 'road') continue;
      final def = BuildingRegistry.get(b.typeId);
      if (def == null) continue;

      switch (def.category) {
        case BuildingCategory.residential:
          resBuildings.add(b);
        case BuildingCategory.commercial:
          comBuildings.add(b);
        case BuildingCategory.industrial:
          indBuildings.add(b);
        case BuildingCategory.publicServices:
        case BuildingCategory.infrastructure:
        case BuildingCategory.environment:
          civicBuildings.add(b);
      }
    }

    final effectivePop = math.max(resBuildings.length * 5, population);
    final nonRoadCount = buildings.where((b) => b.typeId != 'road').length;

    // Time-of-day traffic demand multipliers
    final dayMultiplier = switch (clock.phase) {
      DayPhase.dawn => 0.90,  // Morning commute rush begins
      DayPhase.day => 1.00,   // Full commercial/industrial logistics
      DayPhase.dusk => 0.85,  // Evening return commute
      DayPhase.night => 0.25, // Light quiet streets
    };

    // Public transportation dampens private car demand
    final transitCount = _roadGraph.busStops.length + _roadGraph.busStations.length;
    final transitDamping = transitCount > 0 ? (1.0 - math.min(0.35, transitCount * 0.07)) : 1.0;

    // Scaled dynamic vehicle ceiling
    final dynamicMax = ((nonRoadCount * 3.5) + (effectivePop / 25.0))
        .clamp(8.0, 75.0)
        .round();
    final targetVehicles = math.max(
      nonRoadCount > 0 ? 3 : 0,
      (dynamicMax * dayMultiplier * transitDamping).round().clamp(1, dynamicMax),
    );

    final targetPedestrians = math.max(
      nonRoadCount > 0 ? 4 : 0,
      (maxPedestrians * dayMultiplier * (effectivePop / 80.0)).round().clamp(2, maxPedestrians),
    );

    // ── 1. Realistic OD (Origin-Destination) vehicle spawning ───────────────
    if (_vehicles.length < targetVehicles) {
      _spawnDemandVehicle(
        clock: clock,
        resBuildings: resBuildings,
        comBuildings: comBuildings,
        indBuildings: indBuildings,
        civicBuildings: civicBuildings,
        transitCount: transitCount,
      );
    }

    // ── 2. Pedestrian Spawning ──────────────────────────────────────────────
    if (_pedestrians.length < targetPedestrians) {
      final roadList = _roadGraph.roadTiles.toList();
      final spawnRoad = roadList[_random.nextInt(roadList.length)];
      final connected = _roadGraph.neighborsOf(spawnRoad);

      if (connected.isNotEmpty) {
        final targetRoad = connected[_random.nextInt(connected.length)];
        final heading = CompassDirection.fromGridDelta(spawnRoad, targetRoad) ??
            CompassDirection.se;

        final pedType = _selectPedestrianType(buildings, clock.phase, spawnRoad);
        _pedestrians.add(
          Pedestrian(
            id: 'ped_${_nextPedestrianId++}',
            type: pedType,
            currentTile: spawnRoad,
            nextTile: targetRoad,
            heading: heading,
            sidewalkOffset: _random.nextBool() ? 10.5 : -10.5,
            initialProgress: _random.nextDouble() * 0.25,
          ),
        );
      }
    }
  }

  void _spawnDemandVehicle({
    required SimulationClock clock,
    required List<Building> resBuildings,
    required List<Building> comBuildings,
    required List<Building> indBuildings,
    required List<Building> civicBuildings,
    required int transitCount,
  }) {
    GridPoint? origin;
    GridPoint? dest;
    VehicleType type = VehicleType.sedan;
    String? originId;
    String? destId;

    final roll = _random.nextDouble();

    // Morning commute: Res -> Com/Ind
    if (clock.phase == DayPhase.dawn || (clock.phase == DayPhase.day && roll < 0.45)) {
      if (resBuildings.isNotEmpty && (comBuildings.isNotEmpty || indBuildings.isNotEmpty)) {
        final originB = resBuildings[_random.nextInt(resBuildings.length)];
        final destPool = [...comBuildings, ...indBuildings];
        final destB = destPool[_random.nextInt(destPool.length)];

        origin = _roadGraph.findNearestRoad(GridPoint(originB.x, originB.y));
        dest = _roadGraph.findNearestRoad(GridPoint(destB.x, destB.y));
        originId = originB.id;
        destId = destB.id;
        type = _random.nextBool() ? VehicleType.sedan : VehicleType.suv;
      }
    }
    // Evening return: Com/Ind -> Res
    else if (clock.phase == DayPhase.dusk) {
      if (resBuildings.isNotEmpty && (comBuildings.isNotEmpty || indBuildings.isNotEmpty)) {
        final originPool = [...comBuildings, ...indBuildings];
        final originB = originPool[_random.nextInt(originPool.length)];
        final destB = resBuildings[_random.nextInt(resBuildings.length)];

        origin = _roadGraph.findNearestRoad(GridPoint(originB.x, originB.y));
        dest = _roadGraph.findNearestRoad(GridPoint(destB.x, destB.y));
        originId = originB.id;
        destId = destB.id;
        type = VehicleType.sedan;
      }
    }
    // Freight & Deliveries
    else if (indBuildings.isNotEmpty && comBuildings.isNotEmpty && roll < 0.35) {
      final originB = indBuildings[_random.nextInt(indBuildings.length)];
      final destB = comBuildings[_random.nextInt(comBuildings.length)];

      origin = _roadGraph.findNearestRoad(GridPoint(originB.x, originB.y));
      dest = _roadGraph.findNearestRoad(GridPoint(destB.x, destB.y));
      originId = originB.id;
      destId = destB.id;
      type = _random.nextBool() ? VehicleType.truckCargo : VehicleType.delivery;
    }
    // Public Transit Buses
    else if (transitCount > 0 && roll < 0.25) {
      final roadList = _roadGraph.roadTiles.toList();
      origin = roadList[_random.nextInt(roadList.length)];
      type = VehicleType.bus;
    }

    // Fallback: spawn on random road
    if (origin == null) {
      final roadList = _roadGraph.roadTiles.toList();
      origin = roadList[_random.nextInt(roadList.length)];
      type = _random.nextBool() ? VehicleType.sedan : VehicleType.delivery;
    }

    final neighbors = _roadGraph.neighborsOf(origin);
    if (neighbors.isEmpty) return;
    final nextTile = neighbors[_random.nextInt(neighbors.length)];

    final heading = CompassDirection.fromGridDelta(origin, nextTile) ??
        CompassDirection.se;

    final vehicle = Vehicle(
      id: 'veh_${_nextVehicleId++}',
      type: type,
      currentTile: origin,
      nextTile: nextTile,
      heading: heading,
      originBuildingId: originId,
      destinationBuildingId: destId,
      destinationTile: dest,
    );

    // Compute planned route if destination is defined
    if (dest != null && dest != origin) {
      final route = _roadGraph.findCongestionAwarePath(
        start: origin,
        goal: dest,
        congestionLoads: _congestionMap,
      );
      if (route != null && route.length >= 2) {
        vehicle.assignRoute(route.sublist(1), dest: dest);
      }
    }

    _vehicles.add(vehicle);
  }

  // ── Traffic congestion analytics & Alerts ──────────────────────────────────

  void _analyzeTraffic(List<Building> buildings) {
    _congestionMap.clear();

    // 1. Count vehicles per tile
    final counts = <GridPoint, int>{};
    final speeds = <GridPoint, List<double>>{};

    for (final v in _vehicles) {
      counts[v.currentTile] = (counts[v.currentTile] ?? 0) + 1;
      speeds.putIfAbsent(v.currentTile, () => []).add(v.currentSpeed);
    }

    final segmentStats = <GridPoint, TrafficSegmentStats>{};
    var totalSpeed = 0.0;
    var speedSamples = 0;
    var congestedCount = 0;

    for (final road in _roadGraph.roadTiles) {
      final count = counts[road] ?? 0;
      final tier = _roadGraph.tierAt(road);
      final load = (count / tier.capacity).clamp(0.0, 3.0);
      _congestionMap[road] = load;

      final tileSpeeds = speeds[road];
      final avgTileSpeed = (tileSpeeds != null && tileSpeeds.isNotEmpty)
          ? tileSpeeds.reduce((a, b) => a + b) / tileSpeeds.length
          : tier.speedLimit;

      final condition = TrafficCondition.fromLoadRatio(load);
      if (condition != TrafficCondition.freeFlow) {
        congestedCount++;
      }

      final signal = _roadGraph.signalAt(road);

      segmentStats[road] = TrafficSegmentStats(
        tile: road,
        tier: tier,
        vehicleCount: count,
        condition: condition,
        averageSpeed: avgTileSpeed,
        hasSignal: signal != null,
        signalState: signal?.state,
      );

      totalSpeed += avgTileSpeed;
      speedSamples++;
    }

    // Hotspot detection: sort by load ratio descending
    final sortedRoads = _roadGraph.roadTiles.toList()
      ..sort((a, b) => (_congestionMap[b] ?? 0.0).compareTo(_congestionMap[a] ?? 0.0));
    final hotspots = sortedRoads
        .where((r) => (_congestionMap[r] ?? 0.0) >= 0.70)
        .take(4)
        .toList();

    final citySpeed = speedSamples > 0 ? (totalSpeed / speedSamples) : 48.0;
    final totalRoads = _roadGraph.length;
    final congestionPercent =
        totalRoads > 0 ? ((congestedCount / totalRoads) * 100).round().clamp(0, 100) : 0;

    final overallCondition = TrafficCondition.fromLoadRatio(congestionPercent / 100.0);

    // Public transit impact
    final busCount = _vehicles.where((v) => v.isBus).length;
    final ridership = _vehicles
        .where((v) => v.isBus)
        .fold<int>(0, (sum, v) => sum + v.passengerCount);
    final demandReduction = math.min(35, (busCount * 7) + (_roadGraph.busStops.length * 4));

    // Economic loss estimation ($12 per congested industrial/commercial tile per hour)
    final economicLoss = (congestedCount * 12).clamp(0, 2500);

    // Generate actionable alerts
    final alerts = <TrafficAlert>[];
    final now = DateTime.now();

    for (final hotspot in hotspots) {
      final tier = _roadGraph.tierAt(hotspot);
      final load = _congestionMap[hotspot] ?? 0.0;
      final condition = TrafficCondition.fromLoadRatio(load);

      if (tier.level < 4) {
        final nextTier = RoadTier.fromLevel(tier.level + 1);
        alerts.add(
          TrafficAlert(
            id: 'alt_cong_${hotspot.col}_${hotspot.row}',
            title: '${condition.label} at (${hotspot.col}, ${hotspot.row})',
            message: 'Road is operating at ${(load * 100).round()}% capacity.',
            severity: condition,
            location: hotspot,
            timestamp: now,
            recommendedAction: 'Upgrade to ${nextTier.name} (¢${nextTier.upgradeCost}) to double capacity.',
          ),
        );
      }
    }

    if (transitCount == 0 && congestionPercent >= 25) {
      alerts.add(
        TrafficAlert(
          id: 'alt_transit_needed',
          title: 'Public Transit Recommended',
          message: 'Traffic congestion has reached $congestionPercent%. Building Bus Stops will cut commuter volume.',
          severity: TrafficCondition.moderate,
          location: hotspots.isNotEmpty ? hotspots.first : const GridPoint(0, 0),
          timestamp: now,
          recommendedAction: 'Place Bus Stops and a Bus Terminal to relieve road pressure.',
        ),
      );
    }

    _trafficMetrics = TrafficMetrics(
      totalActiveVehicles: _vehicles.length,
      averageSpeed: citySpeed,
      overallCongestionPercent: congestionPercent,
      condition: overallCondition,
      hotspots: hotspots,
      publicTransitRidership: ridership,
      trafficDemandReductionPercent: demandReduction,
      economicLossPerHour: economicLoss,
      alerts: alerts,
      segmentStats: segmentStats,
    );
  }

  int get transitCount =>
      _roadGraph.busStops.length + _roadGraph.busStations.length;

  PedestrianType _selectPedestrianType(
    List<Building> buildings,
    DayPhase phase,
    GridPoint roadTile,
  ) {
    final nearby = buildings.where((b) {
      if (b.typeId == 'road') return false;
      final dist = (b.x - roadTile.col).abs() + (b.y - roadTile.row).abs();
      return dist <= 3;
    }).toList();

    var nearSchool = false;
    var nearOffice = false;
    var nearShop = false;
    var nearPark = false;
    var nearConstruction = false;

    for (final b in nearby) {
      final def = BuildingRegistry.get(b.typeId);
      if (def == null) continue;
      if (def.id == 'school') nearSchool = true;
      if (def.id == 'office_building') nearOffice = true;
      if (def.category == BuildingCategory.commercial) nearShop = true;
      if (def.category == BuildingCategory.environment) nearPark = true;
      if (b.level < def.maxLevel) nearConstruction = true;
    }

    final roll = _random.nextDouble();

    if (nearSchool && phase.isDay && roll < 0.50) return PedestrianType.student;
    if (nearOffice && (phase == DayPhase.dawn || phase == DayPhase.day) && roll < 0.45) {
      return PedestrianType.officeWorker;
    }
    if (nearShop && phase.isDay && roll < 0.45) return PedestrianType.shopper;
    if (nearPark && roll < 0.55) return PedestrianType.parkVisitor;
    if (nearConstruction && roll < 0.35) return PedestrianType.constructionWorker;

    return PedestrianType.citizen;
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  void clear() {
    _vehicles.clear();
    _pedestrians.clear();
    _pendingSpawns.clear();
    _buildingActivities.clear();
    _trafficMetrics = TrafficMetrics.empty();
    _congestionMap.clear();
    notifyListeners();
  }

  @visibleForTesting
  List<_PendingSpawn> get pendingSpawnsForTest => List.unmodifiable(_pendingSpawns);

  @visibleForTesting
  Map<String, _BuildingActivity> get buildingActivitiesForTest =>
      Map.unmodifiable(_buildingActivities);
}
