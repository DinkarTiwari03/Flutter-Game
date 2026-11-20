import 'dart:async';
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

  /// IDs of entities that were spawned because of this building.
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

  /// Seconds to wait before the action fires.
  double delay;
  final void Function() action;
}

// ─── Main service ─────────────────────────────────────────────────────────────

/// Centralized simulation service managing dynamic vehicles, pedestrians,
/// and urban activity across the city.
///
/// **Immediate building-driven activation**: as soon as [notifyBuildingPlaced]
/// is called (typically right after the player confirms construction) the
/// service schedules a staggered burst of vehicles and pedestrians near that
/// building — no population threshold, no waiting for the next 0.8 s tick.
class UrbanSimulationService extends ChangeNotifier {
  UrbanSimulationService({
    this.maxVehicles = 22,
    this.maxPedestrians = 35,
    math.Random? random,
  }) : _random = random ?? math.Random();

  int maxVehicles;
  int maxPedestrians;
  final math.Random _random;

  final RoadGraph _roadGraph = RoadGraph();
  RoadGraph get roadGraph => _roadGraph;

  final List<Vehicle> _vehicles = [];
  final List<Pedestrian> _pedestrians = [];

  List<Vehicle> get vehicles => List.unmodifiable(_vehicles);
  List<Pedestrian> get pedestrians => List.unmodifiable(_pedestrians);

  int _nextVehicleId = 1;
  int _nextPedestrianId = 1;

  double _spawnTimer = 0.0;
  int _lastBuildingCountHash = -1;

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

  /// Called immediately after the player places [building].
  ///
  /// Schedules a staggered burst of appropriate vehicles and pedestrians near
  /// the building.  Requires the road graph to already be populated (i.e.,
  /// [syncBuildings] must have been called at least once with [GameMap] so that
  /// procedural road tiles are registered).
  void notifyBuildingPlaced(Building building) {
    if (_roadGraph.isEmpty) {
      // Road graph not yet populated; the normal tick spawning will handle it.
      return;
    }

    final def = BuildingRegistry.get(building.typeId);
    if (def == null) return;

    // Ignore pure road placements — they don't generate activity of their own.
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

    // Schedule category-specific staggered spawns.
    _scheduleBuildingActivity(building, def, activity);
  }

  /// Called immediately after [buildingId] is demolished.
  ///
  /// Removes the activity record but intentionally does NOT clear the entities
  /// those buildings spawned — they continue to roam and despawn naturally,
  /// which looks more organic than instant vanishing.
  void notifyBuildingDemolished(String buildingId) {
    _buildingActivities.remove(buildingId);
    // Entities keep their natural life-cycle; no forced despawn here.
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
        // 2–3 citizens, 1 bicycle or motorcycle, 1 sedan — staggered over 4 s
        final citizenCount = 2 + _random.nextInt(2); // 2 or 3
        for (var i = 0; i < citizenCount; i++) {
          _enqueue(
            delay: i * 0.8 + _random.nextDouble() * 0.4,
            action: () => _trySpawnPedestrian(
              road,
              PedestrianType.citizen,
              activity,
            ),
          );
        }
        // bicycle or motorcycle
        _enqueue(
          delay: 1.2 + _random.nextDouble() * 0.6,
          action: () => _trySpawnVehicle(
            road,
            _random.nextBool() ? VehicleType.bicycle : VehicleType.motorcycle,
            activity,
          ),
        );
        // personal car
        _enqueue(
          delay: 2.5 + _random.nextDouble() * 1.0,
          action: () => _trySpawnVehicle(road, VehicleType.sedan, activity),
        );

      case BuildingCategory.commercial:
        // 1 shopper / office worker, 1 delivery van
        _enqueue(
          delay: 0.5 + _random.nextDouble() * 0.5,
          action: () => _trySpawnPedestrian(
            road,
            _random.nextBool()
                ? PedestrianType.shopper
                : PedestrianType.officeWorker,
            activity,
          ),
        );
        _enqueue(
          delay: 1.8 + _random.nextDouble() * 0.8,
          action: () =>
              _trySpawnVehicle(road, VehicleType.delivery, activity),
        );

      case BuildingCategory.industrial:
        // 1 construction worker, 1 cargo truck
        _enqueue(
          delay: 0.6 + _random.nextDouble() * 0.4,
          action: () => _trySpawnPedestrian(
            road,
            PedestrianType.constructionWorker,
            activity,
          ),
        );
        _enqueue(
          delay: 2.0 + _random.nextDouble() * 1.0,
          action: () => _trySpawnVehicle(
            road,
            _random.nextBool() ? VehicleType.truckCargo : VehicleType.truckFlat,
            activity,
          ),
        );

      case BuildingCategory.publicServices:
        // Decide by building id for specific emergency/civic response
        if (def.id == 'hospital') {
          _enqueue(
            delay: 1.0,
            action: () =>
                _trySpawnVehicle(road, VehicleType.ambulance, activity),
          );
        } else if (def.id == 'police_station') {
          _enqueue(
            delay: 1.0,
            action: () => _trySpawnVehicle(road, VehicleType.police, activity),
          );
        } else if (def.id == 'fire_station') {
          _enqueue(
            delay: 1.0,
            action: () =>
                _trySpawnVehicle(road, VehicleType.firetruck, activity),
          );
        } else if (def.id == 'school') {
          _enqueue(
            delay: 0.5,
            action: () => _trySpawnPedestrian(
              road,
              PedestrianType.student,
              activity,
            ),
          );
          _enqueue(
            delay: 1.5,
            action: () =>
                _trySpawnPedestrian(road, PedestrianType.student, activity),
          );
          _enqueue(
            delay: 2.0,
            action: () => _trySpawnVehicle(road, VehicleType.bus, activity),
          );
        } else {
          // Generic civic building — a couple of citizens
          _enqueue(
            delay: 0.8,
            action: () =>
                _trySpawnPedestrian(road, PedestrianType.citizen, activity),
          );
        }

      case BuildingCategory.environment:
        // Parks and gardens: park visitors
        _enqueue(
          delay: 0.4,
          action: () => _trySpawnPedestrian(
            road,
            PedestrianType.parkVisitor,
            activity,
          ),
        );
        _enqueue(
          delay: 1.2 + _random.nextDouble() * 0.6,
          action: () => _trySpawnPedestrian(
            road,
            PedestrianType.parkVisitor,
            activity,
          ),
        );

      case BuildingCategory.infrastructure:
        // Roads and power plants generate no direct civilian pedestrians/vehicles
        break;

      // ignore: unreachable_switch_case — future categories
      default:
        // Fallback: a generic citizen
        _enqueue(
          delay: 0.6,
          action: () =>
              _trySpawnPedestrian(road, PedestrianType.citizen, activity),
        );
    }
  }

  void _enqueue({required double delay, required void Function() action}) {
    _pendingSpawns.add(_PendingSpawn(delay: delay, action: action));
  }

  // ── Entity spawning helpers ────────────────────────────────────────────────

  void _trySpawnVehicle(
    GridPoint road,
    VehicleType type,
    _BuildingActivity? activity,
  ) {
    if (_vehicles.length >= maxVehicles) return;
    final connected = _roadGraph.neighborsOf(road);
    if (connected.isEmpty) return;

    final targetRoad = connected[_random.nextInt(connected.length)];
    final heading =
        CompassDirection.fromGridDelta(road, targetRoad) ?? CompassDirection.se;

    final id = 'veh_${_nextVehicleId++}';
    _vehicles.add(
      Vehicle(
        id: id,
        type: type,
        currentTile: road,
        nextTile: targetRoad,
        heading: heading,
        initialProgress: _random.nextDouble() * 0.2,
      ),
    );
    activity?.spawnedVehicleIds.add(id);
  }

  void _trySpawnPedestrian(
    GridPoint road,
    PedestrianType type,
    _BuildingActivity? activity,
  ) {
    if (_pedestrians.length >= maxPedestrians) return;
    final connected = _roadGraph.neighborsOf(road);
    if (connected.isEmpty) return;

    final targetRoad = connected[_random.nextInt(connected.length)];
    final heading =
        CompassDirection.fromGridDelta(road, targetRoad) ?? CompassDirection.se;

    final id = 'ped_${_nextPedestrianId++}';
    _pedestrians.add(
      Pedestrian(
        id: id,
        type: type,
        currentTile: road,
        nextTile: targetRoad,
        heading: heading,
        sidewalkOffset: _random.nextBool() ? 10.5 : -10.5,
        initialProgress: _random.nextDouble() * 0.2,
      ),
    );
    activity?.spawnedPedestrianIds.add(id);
  }

  // ── Main update loop ───────────────────────────────────────────────────────

  /// Advances the urban life simulation by [dt] seconds.
  void update({
    required double dt,
    required List<Building> buildings,
    required SimulationClock clock,
    int population = 100,
    int happiness = 75,
    GameMap? map,
  }) {
    syncBuildings(buildings, map: map);

    if (_roadGraph.isEmpty) {
      if (_vehicles.isNotEmpty || _pedestrians.isNotEmpty) {
        _vehicles.clear();
        _pedestrians.clear();
        notifyListeners();
      }
      return;
    }

    // Drain staggered spawn queue.
    _drainPendingSpawns(dt);

    // 1. Update vehicle physics, lane progression, and collision spacing
    _updateVehicles(dt);

    // 2. Update pedestrian walking, stride animation, and building visits
    _updatePedestrians(dt);

    // 3. Periodic background spawning influenced by time of day, buildings, pop
    _spawnTimer += dt;
    if (_spawnTimer >= 0.8) {
      _spawnTimer = 0.0;
      _attemptSpawns(
        buildings: buildings,
        clock: clock,
        population: population,
        happiness: happiness,
      );
    }

    notifyListeners();
  }

  void _drainPendingSpawns(double dt) {
    if (_pendingSpawns.isEmpty) return;

    for (final spawn in _pendingSpawns) {
      spawn.delay -= dt;
    }

    // Execute all due jobs (delay ≤ 0) and remove them.
    _pendingSpawns.removeWhere((spawn) {
      if (spawn.delay <= 0.0) {
        spawn.action();
        return true;
      }
      return false;
    });
  }

  // ── Vehicle update ─────────────────────────────────────────────────────────

  void _updateVehicles(double dt) {
    for (var i = 0; i < _vehicles.length; i++) {
      final v = _vehicles[i];
      if (v.isDespawned) continue;

      // Safe following distance check: scan for vehicles ahead on same tile or next tile
      _checkVehicleSpacing(v);

      v.updateMovement(dt);

      if (v.progress >= 1.0) {
        // Reached nextTile: pick subsequent road
        final nextStep = _roadGraph.pickNextRoad(v.nextTile, v.heading, _random);
        if (nextStep != null && nextStep != v.nextTile) {
          v.advanceTo(nextStep);
          // Yield briefly at busy intersections
          if (_roadGraph.isIntersection(v.currentTile) && _random.nextDouble() < 0.25) {
            v.waitTimer = 0.4 + _random.nextDouble() * 0.8;
          }
        } else {
          // Dead end or disconnected: turn around or despawn
          if (_random.nextDouble() < 0.5) {
            v.advanceTo(v.currentTile); // U-turn
          } else {
            v.isDespawned = true;
          }
        }
      }

      v.ageTicks++;
      // Natural lifetime despawn after roaming for ~75-90 seconds
      if (v.ageTicks > 5000 && _random.nextDouble() < 0.05) {
        v.isDespawned = true;
      }
    }

    _vehicles.removeWhere((v) => v.isDespawned);
  }

  void _checkVehicleSpacing(Vehicle v) {
    var mustSlowDown = false;

    for (final other in _vehicles) {
      if (identical(v, other) || other.isDespawned) continue;

      // Distance in world pixels
      final dist = (other.worldPos - v.worldPos).distance;

      // If other vehicle is close ahead in same general heading
      if (dist < 26.0) {
        final toOther = other.worldPos - v.worldPos;
        final headingDot = toOther.dx * v.heading.gridDelta.col + toOther.dy * v.heading.gridDelta.row;

        if (headingDot > 0) {
          mustSlowDown = true;
          break;
        }
      }
    }

    if (mustSlowDown) {
      v.currentSpeed = math.max(6.0, v.baseSpeed * 0.25);
    } else {
      // Smoothly accelerate back to cruising speed
      v.currentSpeed = math.min(v.baseSpeed, v.currentSpeed + 24.0 * 0.016);
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

          // Random pause (e.g. window shopping, crosswalk wait, park bench)
          if (_random.nextDouble() < 0.12) {
            p.idleTimer = 1.0 + _random.nextDouble() * 2.5;
          }
        } else {
          // Reached end of road sidewalk: fade out into building
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

  // ── Periodic background spawning ───────────────────────────────────────────

  /// Evaluates city state and spawns appropriate vehicles and pedestrians.
  ///
  /// Building-driven effective population: even a single residential building
  /// counts as 4 residents so the city feels alive from day one.
  void _attemptSpawns({
    required List<Building> buildings,
    required SimulationClock clock,
    required int population,
    required int happiness,
  }) {
    if (_roadGraph.isEmpty) return;

    // ── Effective population: bypass the threshold for brand-new cities ──
    final resCount = buildings.where((b) {
      if (b.typeId == 'road') return false;
      final def = BuildingRegistry.get(b.typeId);
      return def?.category == BuildingCategory.residential;
    }).length;
    final effectivePop = math.max(resCount * 4, population);

    // ── Building-driven entity minimums ──
    final nonRoadCount =
        buildings.where((b) => b.typeId != 'road').length;
    final minVehicles =
        nonRoadCount > 0 ? nonRoadCount.clamp(1, 3) : 0;
    final minPedestrians =
        nonRoadCount > 0 ? nonRoadCount.clamp(2, 5) : 0;

    // Time-of-day multipliers
    final dayMultiplier = switch (clock.phase) {
      DayPhase.dawn => 0.70,   // Commute starting
      DayPhase.day => 1.00,    // Full urban activity
      DayPhase.dusk => 0.85,   // Evening return
      DayPhase.night => 0.25,  // Quiet night streets
    };

    // Scale targets by pop and day, but respect building minimums
    final popScale = (effectivePop / 100.0).clamp(0.1, 1.5);
    final targetVehicles = math.max(
      minVehicles,
      (maxVehicles * dayMultiplier * popScale).round().clamp(1, maxVehicles),
    );
    final targetPedestrians = math.max(
      minPedestrians,
      (maxPedestrians * dayMultiplier * popScale).round().clamp(1, maxPedestrians),
    );

    // ── 1. Vehicle Spawning ───────────────────────────────────────────────
    if (_vehicles.length < targetVehicles) {
      final roadList = _roadGraph.roadTiles.toList();
      final spawnRoad = roadList[_random.nextInt(roadList.length)];
      final connected = _roadGraph.neighborsOf(spawnRoad);

      if (connected.isNotEmpty) {
        final targetRoad = connected[_random.nextInt(connected.length)];
        final heading =
            CompassDirection.fromGridDelta(spawnRoad, targetRoad) ??
            CompassDirection.se;

        // Choose vehicle type based on nearby buildings and time of day
        final vehicleType = _selectVehicleType(buildings, clock.phase, spawnRoad);

        _vehicles.add(
          Vehicle(
            id: 'veh_${_nextVehicleId++}',
            type: vehicleType,
            currentTile: spawnRoad,
            nextTile: targetRoad,
            heading: heading,
            initialProgress: _random.nextDouble() * 0.3,
          ),
        );
      }
    }

    // ── 2. Pedestrian Spawning ────────────────────────────────────────────
    if (_pedestrians.length < targetPedestrians) {
      final roadList = _roadGraph.roadTiles.toList();
      final spawnRoad = roadList[_random.nextInt(roadList.length)];
      final connected = _roadGraph.neighborsOf(spawnRoad);

      if (connected.isNotEmpty) {
        final targetRoad = connected[_random.nextInt(connected.length)];
        final heading =
            CompassDirection.fromGridDelta(spawnRoad, targetRoad) ??
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
            initialProgress: _random.nextDouble() * 0.3,
          ),
        );
      }
    }
  }

  // ── Type selection helpers ─────────────────────────────────────────────────

  VehicleType _selectVehicleType(
    List<Building> buildings,
    DayPhase phase,
    GridPoint roadTile,
  ) {
    // Find nearby building categories
    final nearbyBuildings = buildings.where((b) {
      if (b.typeId == 'road') return false;
      final dist = (b.x - roadTile.col).abs() + (b.y - roadTile.row).abs();
      return dist <= 4;
    }).toList();

    var hasHospital = false;
    var hasPolice = false;
    var hasFire = false;
    var hasSchool = false;
    var hasCommercial = false;
    var hasIndustrial = false;
    var hasConstruction = false;

    for (final b in nearbyBuildings) {
      final def = BuildingRegistry.get(b.typeId);
      if (def == null) continue;

      if (def.id == 'hospital') hasHospital = true;
      if (def.id == 'police_station') hasPolice = true;
      if (def.id == 'fire_station') hasFire = true;
      if (def.id == 'school') hasSchool = true;
      if (def.category == BuildingCategory.commercial) hasCommercial = true;
      if (def.category == BuildingCategory.industrial) hasIndustrial = true;
      if (b.level < def.maxLevel) hasConstruction = true;
    }

    final roll = _random.nextDouble();

    // Emergency vehicles near civic stations
    if (hasHospital && roll < 0.25) return VehicleType.ambulance;
    if (hasPolice && roll < 0.25) return VehicleType.police;
    if (hasFire && roll < 0.25) return VehicleType.firetruck;

    // School buses near schools in daytime
    if (hasSchool && phase.isDay && roll < 0.30) return VehicleType.bus;

    // Heavy cargo trucks and flatbeds near industrial zones
    if (hasIndustrial && roll < 0.40) {
      return _random.nextBool() ? VehicleType.truckCargo : VehicleType.truckFlat;
    }

    // Delivery vans and taxis near commercial shops
    if (hasCommercial && roll < 0.45) {
      return _random.nextBool() ? VehicleType.delivery : VehicleType.taxi;
    }

    // Construction vehicles near active construction sites
    if (hasConstruction && roll < 0.20) {
      final cRoll = _random.nextInt(3);
      if (cRoll == 0) return VehicleType.tractor;
      if (cRoll == 1) return VehicleType.excavator;
      return VehicleType.cementMixer;
    }

    // Default civilian vehicle pool
    final civRoll = _random.nextInt(6);
    return switch (civRoll) {
      0 => VehicleType.sedan,
      1 => VehicleType.sedanSports,
      2 => VehicleType.suv,
      3 => VehicleType.taxi,
      4 => VehicleType.motorcycle,
      _ => VehicleType.bicycle,
    };
  }

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

  /// Clears all active entities and pending spawns.
  void clear() {
    _vehicles.clear();
    _pedestrians.clear();
    _pendingSpawns.clear();
    _buildingActivities.clear();
    notifyListeners();
  }

  // Expose for testing
  @visibleForTesting
  List<_PendingSpawn> get pendingSpawnsForTest => List.unmodifiable(_pendingSpawns);

  @visibleForTesting
  Map<String, _BuildingActivity> get buildingActivitiesForTest =>
      Map.unmodifiable(_buildingActivities);
}
