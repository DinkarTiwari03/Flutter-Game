/// Mapping from building type ID and level to a bundled PNG asset path.
///
/// Source: Kenney Isometric City and Isometric Landscape packs.
/// License: Creative Commons Zero (CC0) – public domain.
/// Attribution: Kenney (www.kenney.nl) – attribution appreciated but not required.
abstract final class BuildingSpriteRegistry {
  /// Returns the Flutter asset path for a building sprite.
  ///
  /// Falls back to [null] when no sprite exists for the combination,
  /// at which point the caller should fall back to the procedural painter.
  static String? assetFor(String typeId, int level) {
    final clampedLevel = level.clamp(1, 3);
    final key = '$typeId:$clampedLevel';
    return _map[key] ?? _map['$typeId:1'];
  }

  static const _map = <String, String>{
    // ── Residential ──────────────────────────────────────────────────────────
    'small_house:1': 'assets/buildings/residential/small_house_lv1.png',
    'small_house:2': 'assets/buildings/residential/small_house_lv2.png',
    'small_house:3': 'assets/buildings/residential/small_house_lv3.png',

    'apartments:1': 'assets/buildings/residential/apartments_lv1.png',
    'apartments:2': 'assets/buildings/residential/apartments_lv2.png',
    'apartments:3': 'assets/buildings/residential/apartments_lv3.png',

    'residential_tower:1': 'assets/buildings/residential/residential_tower_lv1.png',
    'residential_tower:2': 'assets/buildings/residential/residential_tower_lv2.png',
    'residential_tower:3': 'assets/buildings/residential/residential_tower_lv3.png',

    // ── Commercial ───────────────────────────────────────────────────────────
    'shop:1': 'assets/buildings/commercial/shop_lv1.png',
    'shop:2': 'assets/buildings/commercial/shop_lv2.png',
    'shop:3': 'assets/buildings/commercial/shop_lv3.png',

    'shopping_mall:1': 'assets/buildings/commercial/shopping_mall_lv1.png',
    'shopping_mall:2': 'assets/buildings/commercial/shopping_mall_lv2.png',
    'shopping_mall:3': 'assets/buildings/commercial/shopping_mall_lv3.png',

    'office_building:1': 'assets/buildings/commercial/office_building_lv1.png',
    'office_building:2': 'assets/buildings/commercial/office_building_lv2.png',
    'office_building:3': 'assets/buildings/commercial/office_building_lv3.png',

    // ── Industrial ───────────────────────────────────────────────────────────
    'factory:1': 'assets/buildings/industrial/factory_lv1.png',
    'factory:2': 'assets/buildings/industrial/factory_lv2.png',
    'factory:3': 'assets/buildings/industrial/factory_lv3.png',

    'industrial_facility:1': 'assets/buildings/industrial/industrial_facility_lv1.png',
    'industrial_facility:2': 'assets/buildings/industrial/industrial_facility_lv2.png',
    'industrial_facility:3': 'assets/buildings/industrial/industrial_facility_lv3.png',

    // ── Public Services ──────────────────────────────────────────────────────
    'hospital:1': 'assets/buildings/public_services/hospital_lv1.png',
    'hospital:2': 'assets/buildings/public_services/hospital_lv2.png',
    'hospital:3': 'assets/buildings/public_services/hospital_lv3.png',

    'school:1': 'assets/buildings/public_services/school_lv1.png',
    'school:2': 'assets/buildings/public_services/school_lv2.png',
    'school:3': 'assets/buildings/public_services/school_lv3.png',

    'police_station:1': 'assets/buildings/public_services/police_station_lv1.png',
    'police_station:2': 'assets/buildings/public_services/police_station_lv2.png',
    'police_station:3': 'assets/buildings/public_services/police_station_lv3.png',

    'fire_station:1': 'assets/buildings/public_services/fire_station_lv1.png',
    'fire_station:2': 'assets/buildings/public_services/fire_station_lv2.png',
    'fire_station:3': 'assets/buildings/public_services/fire_station_lv3.png',

    // ── Infrastructure ───────────────────────────────────────────────────────
    'road:1': 'assets/buildings/infrastructure/road.png',

    'power_plant:1': 'assets/buildings/infrastructure/power_plant_lv1.png',
    'power_plant:2': 'assets/buildings/infrastructure/power_plant_lv2.png',
    'power_plant:3': 'assets/buildings/infrastructure/power_plant_lv3.png',

    'water_facility:1': 'assets/buildings/infrastructure/water_facility_lv1.png',
    'water_facility:2': 'assets/buildings/infrastructure/water_facility_lv2.png',
    'water_facility:3': 'assets/buildings/infrastructure/water_facility_lv3.png',

    // ── Environment ──────────────────────────────────────────────────────────
    'park:1': 'assets/buildings/environment/park_lv1.png',
    'park:2': 'assets/buildings/environment/park_lv2.png',
    'park:3': 'assets/buildings/environment/park_lv3.png',

    'garden:1': 'assets/buildings/environment/garden_lv1.png',
    'garden:2': 'assets/buildings/environment/garden_lv2.png',

    'solar_plant:1': 'assets/buildings/environment/solar_plant_lv1.png',
    'solar_plant:2': 'assets/buildings/environment/solar_plant_lv2.png',
    'solar_plant:3': 'assets/buildings/environment/solar_plant_lv3.png',

    'water_treatment:1': 'assets/buildings/environment/water_treatment_lv1.png',
    'water_treatment:2': 'assets/buildings/environment/water_treatment_lv2.png',
    'water_treatment:3': 'assets/buildings/environment/water_treatment_lv3.png',
  };
}
