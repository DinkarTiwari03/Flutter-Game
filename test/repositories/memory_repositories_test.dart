import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/models/mission_progress.dart';
import 'package:city_builder_2040/models/player_progress.dart';
import 'package:city_builder_2040/models/resource_ledger.dart';
import 'package:city_builder_2040/repositories/building_repository.dart';
import 'package:city_builder_2040/repositories/city_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_building_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_city_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_mission_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_player_progress_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_resource_repository.dart';
import 'package:city_builder_2040/repositories/mission_repository.dart';
import 'package:city_builder_2040/repositories/player_progress_repository.dart';
import 'package:city_builder_2040/repositories/resource_repository.dart';

final _t0 = DateTime.utc(2040, 1, 1);
final _t1 = DateTime.utc(2040, 1, 2);

City _city(String id, {DateTime? updatedAt}) => City(
  id: id,
  name: 'City $id',
  mapWidth: 32,
  mapHeight: 32,
  createdAt: _t0,
  updatedAt: updatedAt ?? _t0,
);

Building _building(String id, {String cityId = 'c1'}) => Building(
  id: id,
  cityId: cityId,
  typeId: 'residential',
  x: 1,
  y: 2,
  createdAt: _t0,
  updatedAt: _t0,
);

void main() {
  group('model JSON round trip', () {
    test('City', () {
      final city = _city('c1').copyWith(day: 5, population: 120);
      final copy = City.fromJson(city.toJson());
      expect(copy.toJson(), city.toJson());
      expect(copy.updatedAt.isAtSameMomentAs(city.updatedAt), isTrue);
    });

    test('Building', () {
      final copy = Building.fromJson(_building('b1').toJson());
      expect(copy.toJson(), _building('b1').toJson());
    });

    test('ResourceLedger', () {
      final ledger = ResourceLedger(
        cityId: 'c1',
        amounts: {'money': 1000, 'power': 12.5},
        updatedAt: _t0,
      );
      final copy = ResourceLedger.fromJson(ledger.toJson());
      expect(copy.amountOf('money'), 1000);
      expect(copy.amountOf('power'), 12.5);
      expect(copy.amountOf('water'), 0);
    });

    test('MissionProgress', () {
      final progress = MissionProgress(
        cityId: 'c1',
        missionId: 'm1',
        status: MissionStatus.active,
        progress: 0.5,
        updatedAt: _t0,
      );
      final copy = MissionProgress.fromJson(progress.toJson());
      expect(copy.status, MissionStatus.active);
      expect(copy.progress, 0.5);
    });

    test('PlayerProgress', () {
      final progress = PlayerProgress(
        playerId: PlayerProgress.localPlayerId,
        level: 3,
        experience: 450,
        unlockedIds: ['park', 'power_plant'],
        updatedAt: _t0,
      );
      final copy = PlayerProgress.fromJson(progress.toJson());
      expect(copy.level, 3);
      expect(copy.unlockedIds, ['park', 'power_plant']);
    });
  });

  group('CityRepository', () {
    late CityRepository repo;
    setUp(() => repo = MemoryCityRepository());

    test('returns null and empty list when nothing is stored', () async {
      expect(await repo.getCity('missing'), isNull);
      expect(await repo.listCities(), isEmpty);
    });

    test('save is an upsert', () async {
      await repo.saveCity(_city('c1'));
      await repo.saveCity(_city('c1').copyWith(name: 'Renamed'));
      final cities = await repo.listCities();
      expect(cities, hasLength(1));
      expect(cities.single.name, 'Renamed');
    });

    test('lists most recently updated first', () async {
      await repo.saveCity(_city('old'));
      await repo.saveCity(_city('new', updatedAt: _t1));
      final ids = (await repo.listCities()).map((c) => c.id);
      expect(ids, ['new', 'old']);
    });

    test('delete is idempotent', () async {
      await repo.saveCity(_city('c1'));
      await repo.deleteCity('c1');
      await repo.deleteCity('c1');
      expect(await repo.getCity('c1'), isNull);
    });
  });

  group('BuildingRepository', () {
    late BuildingRepository repo;
    setUp(() => repo = MemoryBuildingRepository());

    test('keeps buildings separate per city', () async {
      await repo.saveBuildings([
        _building('b1'),
        _building('b2'),
        _building('b3', cityId: 'c2'),
      ]);
      expect(await repo.getBuildings('c1'), hasLength(2));
      expect(await repo.getBuildings('c2'), hasLength(1));
    });

    test('save upserts and remove deletes one building', () async {
      await repo.saveBuilding(_building('b1'));
      await repo.saveBuilding(_building('b1').copyWith(level: 2));
      expect((await repo.getBuildings('c1')).single.level, 2);

      await repo.removeBuilding('c1', 'b1');
      expect(await repo.getBuildings('c1'), isEmpty);
    });

    test('deleteByCity only affects that city', () async {
      await repo.saveBuildings([
        _building('b1'),
        _building('b2', cityId: 'c2'),
      ]);
      await repo.deleteByCity('c1');
      await repo.deleteByCity('c1');
      expect(await repo.getBuildings('c1'), isEmpty);
      expect(await repo.getBuildings('c2'), hasLength(1));
    });
  });

  group('ResourceRepository', () {
    late ResourceRepository repo;
    setUp(() => repo = MemoryResourceRepository());

    test('stores, replaces and deletes a ledger', () async {
      expect(await repo.getLedger('c1'), isNull);

      await repo.saveLedger(
        ResourceLedger(cityId: 'c1', amounts: {'money': 1}, updatedAt: _t0),
      );
      await repo.saveLedger(
        ResourceLedger(cityId: 'c1', amounts: {'money': 2}, updatedAt: _t1),
      );
      expect((await repo.getLedger('c1'))!.amountOf('money'), 2);

      await repo.deleteByCity('c1');
      expect(await repo.getLedger('c1'), isNull);
    });
  });

  group('MissionRepository', () {
    late MissionRepository repo;
    setUp(() => repo = MemoryMissionRepository());

    MissionProgress mission(String id, {String cityId = 'c1'}) =>
        MissionProgress(cityId: cityId, missionId: id, updatedAt: _t0);

    test('stores progress per city and mission', () async {
      await repo.saveProgress(mission('m1'));
      await repo.saveProgress(
        mission('m1').copyWith(status: MissionStatus.completed, progress: 1),
      );
      await repo.saveProgress(mission('m2'));
      await repo.saveProgress(mission('m1', cityId: 'c2'));

      final c1 = await repo.getProgress('c1');
      expect(c1, hasLength(2));
      expect(
        c1.firstWhere((m) => m.missionId == 'm1').status,
        MissionStatus.completed,
      );
    });

    test('deleteByCity only affects that city', () async {
      await repo.saveProgress(mission('m1'));
      await repo.saveProgress(mission('m1', cityId: 'c2'));
      await repo.deleteByCity('c1');
      expect(await repo.getProgress('c1'), isEmpty);
      expect(await repo.getProgress('c2'), hasLength(1));
    });
  });

  group('PlayerProgressRepository', () {
    late PlayerProgressRepository repo;
    setUp(() => repo = MemoryPlayerProgressRepository());

    test('stores and replaces progress by player id', () async {
      expect(await repo.getProgress(PlayerProgress.localPlayerId), isNull);

      await repo.saveProgress(
        PlayerProgress(playerId: PlayerProgress.localPlayerId, updatedAt: _t0),
      );
      await repo.saveProgress(
        PlayerProgress(
          playerId: PlayerProgress.localPlayerId,
          level: 2,
          updatedAt: _t1,
        ),
      );
      final stored = await repo.getProgress(PlayerProgress.localPlayerId);
      expect(stored!.level, 2);
    });
  });
}
