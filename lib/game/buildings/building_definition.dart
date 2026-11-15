import 'package:flutter/material.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';

/// Categories of buildings available in City Builder 2040.
enum BuildingCategory {
  residential('Residential', Icons.home_rounded, AppColors.teal),
  commercial('Commercial', Icons.storefront_rounded, AppColors.sky),
  industrial('Industrial', Icons.factory_rounded, AppColors.sunrise),
  publicServices(
    'Public Services',
    Icons.local_hospital_rounded,
    AppColors.coral,
  ),
  infrastructure('Infrastructure', Icons.bolt_rounded, AppColors.navy),
  environment('Environment', Icons.park_rounded, AppColors.aqua);

  const BuildingCategory(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;
}

/// Reusable definition of a constructible building type.
class BuildingDefinition {
  const BuildingDefinition({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.width,
    required this.height,
    required this.cost,
    required this.baseUpgradeCost,
    this.maxLevel = 3,
    required this.icon,
    this.color,
  });

  final String id;
  final String name;
  final BuildingCategory category;
  final String description;

  /// Width in grid tiles along the column axis.
  final int width;

  /// Height in grid tiles along the row axis.
  final int height;

  /// Base construction cost in coins.
  final int cost;

  /// Base upgrade cost in coins for level 1 -> 2.
  final int baseUpgradeCost;

  /// Maximum upgrade tier.
  final int maxLevel;

  final IconData icon;
  final Color? color;

  Color get accentColor => color ?? category.color;

  /// Whether this building is a road segment.
  bool get isRoad => id == 'road';

  /// Total number of tiles occupied by this building.
  int get tileCount => width * height;

  /// Generates all [GridPoint]s occupied by this building with its top-left
  /// corner placed at [origin].
  List<GridPoint> footprintTiles(GridPoint origin) {
    final tiles = <GridPoint>[];
    for (var dr = 0; dr < height; dr++) {
      for (var dc = 0; dc < width; dc++) {
        tiles.add(GridPoint(origin.col + dc, origin.row + dr));
      }
    }
    return tiles;
  }

  /// Calculates the cost to upgrade from [currentLevel] to [currentLevel] + 1.
  /// Returns null if the building is already at its maximum level.
  int? upgradeCost(int currentLevel) {
    if (currentLevel >= maxLevel) return null;
    return (baseUpgradeCost * (1.0 + (currentLevel - 1) * 0.75)).round();
  }

  /// Calculates the demolition refund in coins based on [currentLevel].
  /// Standard refund is 50% of base cost plus 50% of invested upgrade costs.
  int demolitionRefund(int currentLevel) {
    var totalInvested = cost;
    for (var lvl = 1; lvl < currentLevel; lvl++) {
      totalInvested += upgradeCost(lvl) ?? 0;
    }
    return (totalInvested * 0.5).round();
  }
}

/// Registry of all standard building definitions.
abstract final class BuildingRegistry {
  // Residential
  static const smallHouse = BuildingDefinition(
    id: 'small_house',
    name: 'Small House',
    category: BuildingCategory.residential,
    description: 'Cozy single-family home. Low density.',
    width: 1,
    height: 1,
    cost: 150,
    baseUpgradeCost: 100,
    maxLevel: 3,
    icon: Icons.cottage_rounded,
  );

  static const apartments = BuildingDefinition(
    id: 'apartments',
    name: 'Apartments',
    category: BuildingCategory.residential,
    description: 'Multi-family residential complex. Medium density.',
    width: 2,
    height: 2,
    cost: 600,
    baseUpgradeCost: 400,
    maxLevel: 3,
    icon: Icons.apartment_rounded,
  );

  static const residentialTower = BuildingDefinition(
    id: 'residential_tower',
    name: 'Residential Tower',
    category: BuildingCategory.residential,
    description: 'High-rise residential skyscraper. High density.',
    width: 2,
    height: 2,
    cost: 1800,
    baseUpgradeCost: 1200,
    maxLevel: 4,
    icon: Icons.location_city_rounded,
  );

  // Commercial
  static const shop = BuildingDefinition(
    id: 'shop',
    name: 'Shop',
    category: BuildingCategory.commercial,
    description: 'Local retail store and convenience market.',
    width: 1,
    height: 1,
    cost: 250,
    baseUpgradeCost: 150,
    maxLevel: 3,
    icon: Icons.storefront_rounded,
  );

  static const shoppingMall = BuildingDefinition(
    id: 'shopping_mall',
    name: 'Shopping Mall',
    category: BuildingCategory.commercial,
    description: 'Sprawling commercial retail and dining center.',
    width: 2,
    height: 2,
    cost: 1200,
    baseUpgradeCost: 800,
    maxLevel: 3,
    icon: Icons.local_mall_rounded,
  );

  static const officeBuilding = BuildingDefinition(
    id: 'office_building',
    name: 'Office Building',
    category: BuildingCategory.commercial,
    description: 'Corporate headquarters and tech office tower.',
    width: 2,
    height: 2,
    cost: 2400,
    baseUpgradeCost: 1500,
    maxLevel: 4,
    icon: Icons.domain_rounded,
  );

  // Industrial
  static const factory = BuildingDefinition(
    id: 'factory',
    name: 'Factory',
    category: BuildingCategory.industrial,
    description: 'Standard manufacturing facility.',
    width: 2,
    height: 2,
    cost: 900,
    baseUpgradeCost: 600,
    maxLevel: 3,
    icon: Icons.factory_rounded,
  );

  static const industrialFacility = BuildingDefinition(
    id: 'industrial_facility',
    name: 'Industrial Complex',
    category: BuildingCategory.industrial,
    description: 'Heavy industrial advanced manufacturing plant.',
    width: 3,
    height: 3,
    cost: 2500,
    baseUpgradeCost: 1600,
    maxLevel: 3,
    icon: Icons.precision_manufacturing_rounded,
  );

  // Public services
  static const hospital = BuildingDefinition(
    id: 'hospital',
    name: 'Hospital',
    category: BuildingCategory.publicServices,
    description: 'City medical center providing healthcare coverage.',
    width: 2,
    height: 2,
    cost: 1500,
    baseUpgradeCost: 1000,
    maxLevel: 3,
    icon: Icons.local_hospital_rounded,
  );

  static const school = BuildingDefinition(
    id: 'school',
    name: 'School',
    category: BuildingCategory.publicServices,
    description: 'Educational institution for young citizens.',
    width: 2,
    height: 2,
    cost: 1000,
    baseUpgradeCost: 700,
    maxLevel: 3,
    icon: Icons.school_rounded,
  );

  static const policeStation = BuildingDefinition(
    id: 'police_station',
    name: 'Police Station',
    category: BuildingCategory.publicServices,
    description: 'Maintains public safety and prevents crime.',
    width: 1,
    height: 1,
    cost: 500,
    baseUpgradeCost: 350,
    maxLevel: 3,
    icon: Icons.local_police_rounded,
  );

  static const fireStation = BuildingDefinition(
    id: 'fire_station',
    name: 'Fire Station',
    category: BuildingCategory.publicServices,
    description: 'Emergency fire prevention and response squad.',
    width: 1,
    height: 1,
    cost: 500,
    baseUpgradeCost: 350,
    maxLevel: 3,
    icon: Icons.fire_truck_rounded,
  );

  // Infrastructure
  static const road = BuildingDefinition(
    id: 'road',
    name: 'Road',
    category: BuildingCategory.infrastructure,
    description: 'Paved transit route connecting city zones.',
    width: 1,
    height: 1,
    cost: 25,
    baseUpgradeCost: 0,
    maxLevel: 1,
    icon: Icons.add_road_rounded,
  );

  static const powerPlant = BuildingDefinition(
    id: 'power_plant',
    name: 'Power Plant',
    category: BuildingCategory.infrastructure,
    description: 'Thermal clean energy power generation facility.',
    width: 2,
    height: 2,
    cost: 2000,
    baseUpgradeCost: 1400,
    maxLevel: 3,
    icon: Icons.bolt_rounded,
  );

  static const waterFacility = BuildingDefinition(
    id: 'water_facility',
    name: 'Water Facility',
    category: BuildingCategory.infrastructure,
    description: 'Pumps and distributes clean drinking water.',
    width: 2,
    height: 2,
    cost: 1200,
    baseUpgradeCost: 800,
    maxLevel: 3,
    icon: Icons.water_drop_rounded,
  );

  // Environment
  static const park = BuildingDefinition(
    id: 'park',
    name: 'City Park',
    category: BuildingCategory.environment,
    description: 'Public green area with pathways and benches.',
    width: 2,
    height: 2,
    cost: 400,
    baseUpgradeCost: 250,
    maxLevel: 3,
    icon: Icons.park_rounded,
  );

  static const garden = BuildingDefinition(
    id: 'garden',
    name: 'Botanical Garden',
    category: BuildingCategory.environment,
    description: 'Floral garden boosting local citizen happiness.',
    width: 1,
    height: 1,
    cost: 150,
    baseUpgradeCost: 100,
    maxLevel: 2,
    icon: Icons.yard_rounded,
  );

  static const solarPlant = BuildingDefinition(
    id: 'solar_plant',
    name: 'Solar Plant',
    category: BuildingCategory.environment,
    description: 'Eco-friendly renewable solar panel array.',
    width: 2,
    height: 2,
    cost: 1600,
    baseUpgradeCost: 1100,
    maxLevel: 3,
    icon: Icons.solar_power_rounded,
  );

  static const waterTreatment = BuildingDefinition(
    id: 'water_treatment',
    name: 'Water Treatment',
    category: BuildingCategory.environment,
    description: 'Purifies wastewater and prevents pollution.',
    width: 2,
    height: 2,
    cost: 1400,
    baseUpgradeCost: 950,
    maxLevel: 3,
    icon: Icons.waves_rounded,
  );

  /// Map of all registered buildings by their unique [id].
  static final Map<String, BuildingDefinition> all = {
    smallHouse.id: smallHouse,
    apartments.id: apartments,
    residentialTower.id: residentialTower,
    shop.id: shop,
    shoppingMall.id: shoppingMall,
    officeBuilding.id: officeBuilding,
    factory.id: factory,
    industrialFacility.id: industrialFacility,
    hospital.id: hospital,
    school.id: school,
    policeStation.id: policeStation,
    fireStation.id: fireStation,
    road.id: road,
    powerPlant.id: powerPlant,
    waterFacility.id: waterFacility,
    park.id: park,
    garden.id: garden,
    solarPlant.id: solarPlant,
    waterTreatment.id: waterTreatment,
  };

  /// Retrieves a building definition by its string [typeId].
  static BuildingDefinition? get(String typeId) => all[typeId];

  /// Lists all building definitions matching the given [category].
  static List<BuildingDefinition> byCategory(BuildingCategory category) {
    return all.values.where((b) => b.category == category).toList();
  }
}
