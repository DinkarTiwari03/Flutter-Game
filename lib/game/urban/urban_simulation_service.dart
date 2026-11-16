import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/game/urban/compass_direction.dart';
import 'package:city_builder_2040/game/urban/pedestrian.dart';
import 'package:city_builder_2040/game/urban/road_graph.dart';
import 'package:city_builder_2040/game/urban/vehicle.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/simulation_clock.dart';

/// Centralized simulation service managing dynamic vehicles, pedestrians,
/// and urban activity across the city.
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

    // 1. Update vehicle physics, lane progression, and collision spacing
    _updateVehicles(dt);

    // 2. Update pedestrian walking, stride animation, and building visits
    _updatePedestrians(dt);

    // 3. Periodic spawning influenced by time of day, buildings, and happiness
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

  /// Evaluates city state and spawns appropriate vehicles and pedestrians.
  void _attemptSpawns({
    required List<Building> buildings,
    required SimulationClock clock,
    required int population,
    required int happiness,
  }) {
    if (_roadGraph.isEmpty) return;

    // Time-of-day multipliers
    final dayMultiplier = switch (clock.phase) {
      DayPhase.dawn => 0.70,   // Commute starting
      DayPhase.day => 1.00,    // Full urban activity
      DayPhase.dusk => 0.85,   // Evening return
      DayPhase.night => 0.25,  // Quiet night streets
    };

    final targetVehicles = (maxVehicles * dayMultiplier).round();
    final effectiveMaxVehicles = targetVehicles.clamp(1, math.max(1, maxVehicles));

    final targetPedestrians = (maxPedestrians * dayMultiplier).round();
    final effectiveMaxPedestrians = targetPedestrians.clamp(1, math.max(1, maxPedestrians));

    // ── 1. Vehicle Spawning ────────────────────────────────────────────────
    if (_vehicles.length < effectiveMaxVehicles) {
      final roadList = _roadGraph.roadTiles.toList();
      final spawnRoad = roadList[_random.nextInt(roadList.length)];
      final connected = _roadGraph.neighborsOf(spawnRoad);

      if (connected.isNotEmpty) {
        final targetRoad = connected[_random.nextInt(connected.length)];
        final heading = CompassDirection.fromGridDelta(spawnRoad, targetRoad) ?? CompassDirection.se;

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

    // ── 2. Pedestrian Spawning ─────────────────────────────────────────────
    if (_pedestrians.length < effectiveMaxPedestrians) {
      final roadList = _roadGraph.roadTiles.toList();
      final spawnRoad = roadList[_random.nextInt(roadList.length)];
      final connected = _roadGraph.neighborsOf(spawnRoad);

      if (connected.isNotEmpty) {
        final targetRoad = connected[_random.nextInt(connected.length)];
        final heading = CompassDirection.fromGridDelta(spawnRoad, targetRoad) ?? CompassDirection.se;

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

  /// Clears all active entities.
  void clear() {
    _vehicles.clear();
    _pedestrians.clear();
    notifyListeners();
  }
}
