import 'package:flutter_test/flutter_test.dart';
import 'package:city_builder_2040/core/utils/app_exception.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/models/mission_progress.dart';
import 'package:city_builder_2040/models/resource_ledger.dart';
import 'package:city_builder_2040/repositories/memory/memory_building_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_city_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_mission_repository.dart';
import 'package:city_builder_2040/repositories/memory/memory_resource_repository.dart';
import 'package:city_builder_2040/services/city_service.dart';

void main() {
  late MemoryCityRepository cities;
  late MemoryBuildingRepository buildings;
  late MemoryResourceRepository resources;
  late MemoryMissionRepository missions;
  late DateTime now;
  late CityService service;

  setUp(() {
    cities = MemoryCityRepository();
    buildings = MemoryBuildingRepository();
    resources = MemoryResourceRepository();
    missions = MemoryMissionRepository();
    now = DateTime.utc(2040, 1, 1);
    service = CityService(
      cities: cities,
      buildings: buildings,
      resources: resources,
      missions: missions,
      clock: () => now,
    );
  });

  test(
    'createCity trims the name, stores the city and assigns an id',
    () async {
      final city = await service.createCity(name: '  Neo Harbor  ');

      expect(city.name, 'Neo Harbor');
      expect(city.id, isNotEmpty);
      expect((await cities.getCity(city.id))!.name, 'Neo Harbor');
      final ledger = await resources.getLedger(city.id);
      expect(ledger, isNotNull);
      expect(ledger!.coins, 25000);
    },
  );

  test('createCity gives each city a distinct id', () async {
    final a = await service.createCity(name: 'A');
    final b = await service.createCity(name: 'B');
    expect(a.id, isNot(b.id));
  });

  test('createCity rejects invalid input without storing anything', () async {
    await expectLater(
      service.createCity(name: '   '),
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      service.createCity(name: 'x' * 100),
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      service.createCity(name: 'Ok', mapWidth: 0),
      throwsA(isA<ValidationException>()),
    );
    expect(await cities.listCities(), isEmpty);
  });

  test('latestCity and hasSavedCity reflect stored cities', () async {
    expect(await service.hasSavedCity(), isFalse);
    expect(await service.latestCity(), isNull);

    await service.createCity(name: 'First');
    now = now.add(const Duration(days: 1));
    final second = await service.createCity(name: 'Second');

    expect(await service.hasSavedCity(), isTrue);
    expect((await service.latestCity())!.id, second.id);
  });

  test('deleteCity removes the city and all of its data only', () async {
    final keep = await service.createCity(name: 'Keep');
    final drop = await service.createCity(name: 'Drop');

    for (final city in [keep, drop]) {
      await buildings.saveBuilding(
        Building(
          id: 'b-${city.id}',
          cityId: city.id,
          typeId: 'park',
          x: 0,
          y: 0,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await resources.saveLedger(
        ResourceLedger(cityId: city.id, amounts: {'money': 1}, updatedAt: now),
      );
      await missions.saveProgress(
        MissionProgress(cityId: city.id, missionId: 'm1', updatedAt: now),
      );
    }

    await service.deleteCity(drop.id);

    expect(await cities.getCity(drop.id), isNull);
    expect(await buildings.getBuildings(drop.id), isEmpty);
    expect(await resources.getLedger(drop.id), isNull);
    expect(await missions.getProgress(drop.id), isEmpty);

    expect(await cities.getCity(keep.id), isNotNull);
    expect(await buildings.getBuildings(keep.id), hasLength(1));
    expect(await resources.getLedger(keep.id), isNotNull);
    expect(await missions.getProgress(keep.id), hasLength(1));
  });
}
