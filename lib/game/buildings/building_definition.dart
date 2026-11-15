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

/// Data-driven configuration for a building's resource generation and consumption.
class BuildingResourceConfig {
  const BuildingResourceConfig({
    this.housingCapacity = 0,
    this.residentialTaxPerResident = 0.0,
    this.commercialIncome = 0,
    this.industrialIncome = 0,
    this.maintenanceCost = 0,
    this.electricityProduction = 0,
    this.electricityConsumption = 0,
    this.waterProduction = 0,
    this.waterConsumption = 0,
    this.pollutionOutput = 0,
    this.pollutionReduction = 0,
    this.happinessBonus = 0,
    this.jobsProvided = 0,
    this.healthcareCapacity = 0,
    this.educationCapacity = 0,
    this.safetyCapacity = 0,
  });

  /// Maximum residents this building can house (residential).
  final int housingCapacity;

  /// Coins generated per citizen living in this building per tick.
  final double residentialTaxPerResident;

  /// Direct coins generated per tick (commercial).
  final int commercialIncome;

  /// Direct coins generated per tick (industrial).
  final int industrialIncome;

  /// Operating cost in coins deducted per tick.
  final int maintenanceCost;

  /// Electricity generated in kW per tick (power plants, solar).
  final int electricityProduction;

  /// Electricity consumed in kW per tick.
  final int electricityConsumption;

  /// Water generated in kL per tick (water facilities).
  final int waterProduction;

  /// Water consumed in kL per tick.
  final int waterConsumption;

  /// Environmental pollution units added per tick (factories, power plants).
  final int pollutionOutput;

  /// Environmental pollution units scrubbed/mitigated per tick (parks, treatment).
  final int pollutionReduction;

  /// Direct positive contribution to city happiness rating.
  final int happinessBonus;

  /// Number of jobs provided by this facility.
  final int jobsProvided;

  /// Healthcare coverage capacity provided for citizens (hospitals).
  final int healthcareCapacity;

  /// Educational seat capacity provided for citizens (schools).
  final int educationCapacity;

  /// Public safety coverage provided for citizens (police/fire).
  final int safetyCapacity;
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
    this.requiredPlayerLevel = 1,
    required this.icon,
    this.color,
    this.resources = const BuildingResourceConfig(),
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

  /// Minimum player level required to unlock and construct this building.
  final int requiredPlayerLevel;

  final IconData icon;
  final Color? color;

  /// Resource production, consumption, and economic behavior.
  final BuildingResourceConfig resources;

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

  // Tier-scaled resource calculations:

  /// Effective housing capacity at [level].
  int effectiveHousingCapacity(int level) {
    if (resources.housingCapacity <= 0) return 0;
    return (resources.housingCapacity * (1.0 + (level - 1) * 0.5)).round();
  }

  /// Effective commercial income at [level].
  int effectiveCommercialIncome(int level) {
    if (resources.commercialIncome <= 0) return 0;
    return (resources.commercialIncome * (1.0 + (level - 1) * 0.4)).round();
  }

  /// Effective industrial income at [level].
  int effectiveIndustrialIncome(int level) {
    if (resources.industrialIncome <= 0) return 0;
    return (resources.industrialIncome * (1.0 + (level - 1) * 0.5)).round();
  }

  /// Effective residential tax collected for [residents] housed in this building at [level].
  int effectiveResidentialTax(int level, int residents) {
    if (resources.residentialTaxPerResident <= 0 || residents <= 0) return 0;
    final rateMultiplier = 1.0 + (level - 1) * 0.2;
    return (residents * resources.residentialTaxPerResident * rateMultiplier)
        .round();
  }

  /// Effective operating maintenance cost at [level].
  int effectiveMaintenance(int level) {
    if (resources.maintenanceCost <= 0) return 0;
    return (resources.maintenanceCost * (1.0 + (level - 1) * 0.35)).round();
  }

  /// Effective electricity generation in kW at [level].
  int effectiveElectricityProduction(int level) {
    if (resources.electricityProduction <= 0) return 0;
    return (resources.electricityProduction * (1.0 + (level - 1) * 0.5)).round();
  }

  /// Effective electricity consumption in kW at [level].
  int effectiveElectricityConsumption(int level) {
    if (resources.electricityConsumption <= 0) return 0;
    return (resources.electricityConsumption * (1.0 + (level - 1) * 0.3)).round();
  }

  /// Effective water generation in kL at [level].
  int effectiveWaterProduction(int level) {
    if (resources.waterProduction <= 0) return 0;
    return (resources.waterProduction * (1.0 + (level - 1) * 0.5)).round();
  }

  /// Effective water consumption in kL at [level].
  int effectiveWaterConsumption(int level) {
    if (resources.waterConsumption <= 0) return 0;
    return (resources.waterConsumption * (1.0 + (level - 1) * 0.3)).round();
  }

  /// Effective environmental pollution output at [level].
  int effectivePollutionOutput(int level) {
    if (resources.pollutionOutput <= 0) return 0;
    return (resources.pollutionOutput * (1.0 + (level - 1) * 0.25)).round();
  }

  /// Effective environmental pollution reduction at [level].
  int effectivePollutionReduction(int level) {
    if (resources.pollutionReduction <= 0) return 0;
    return (resources.pollutionReduction * (1.0 + (level - 1) * 0.4)).round();
  }

  /// Effective happiness bonus contributed at [level].
  int effectiveHappinessBonus(int level) {
    if (resources.happinessBonus <= 0) return 0;
    return (resources.happinessBonus * (1.0 + (level - 1) * 0.3)).round();
  }

  /// Effective employment jobs provided at [level].
  int effectiveJobsProvided(int level) {
    if (resources.jobsProvided <= 0) return 0;
    return (resources.jobsProvided * (1.0 + (level - 1) * 0.4)).round();
  }

  /// Effective healthcare capacity provided at [level].
  int effectiveHealthcareCapacity(int level) {
    if (resources.healthcareCapacity <= 0) return 0;
    return (resources.healthcareCapacity * (1.0 + (level - 1) * 0.5)).round();
  }

  /// Effective education capacity provided at [level].
  int effectiveEducationCapacity(int level) {
    if (resources.educationCapacity <= 0) return 0;
    return (resources.educationCapacity * (1.0 + (level - 1) * 0.5)).round();
  }

  /// Effective public safety capacity provided at [level].
  int effectiveSafetyCapacity(int level) {
    if (resources.safetyCapacity <= 0) return 0;
    return (resources.safetyCapacity * (1.0 + (level - 1) * 0.5)).round();
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
    resources: BuildingResourceConfig(
      housingCapacity: 12,
      residentialTaxPerResident: 1.5,
      maintenanceCost: 2,
      electricityConsumption: 3,
      waterConsumption: 3,
    ),
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
    resources: BuildingResourceConfig(
      housingCapacity: 60,
      residentialTaxPerResident: 1.5,
      maintenanceCost: 8,
      electricityConsumption: 15,
      waterConsumption: 15,
    ),
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
    requiredPlayerLevel: 3,
    icon: Icons.location_city_rounded,
    resources: BuildingResourceConfig(
      housingCapacity: 240,
      residentialTaxPerResident: 1.8,
      maintenanceCost: 30,
      electricityConsumption: 45,
      waterConsumption: 45,
    ),
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
    resources: BuildingResourceConfig(
      commercialIncome: 45,
      maintenanceCost: 5,
      electricityConsumption: 5,
      waterConsumption: 4,
      jobsProvided: 12,
    ),
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
    requiredPlayerLevel: 2,
    icon: Icons.local_mall_rounded,
    resources: BuildingResourceConfig(
      commercialIncome: 200,
      maintenanceCost: 25,
      electricityConsumption: 30,
      waterConsumption: 25,
      jobsProvided: 55,
    ),
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
    requiredPlayerLevel: 3,
    icon: Icons.domain_rounded,
    resources: BuildingResourceConfig(
      commercialIncome: 420,
      maintenanceCost: 50,
      electricityConsumption: 55,
      waterConsumption: 40,
      jobsProvided: 150,
    ),
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
    resources: BuildingResourceConfig(
      industrialIncome: 150,
      maintenanceCost: 20,
      electricityConsumption: 40,
      waterConsumption: 35,
      pollutionOutput: 25,
      jobsProvided: 40,
    ),
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
    requiredPlayerLevel: 2,
    icon: Icons.precision_manufacturing_rounded,
    resources: BuildingResourceConfig(
      industrialIncome: 450,
      maintenanceCost: 60,
      electricityConsumption: 110,
      waterConsumption: 90,
      pollutionOutput: 65,
      jobsProvided: 120,
    ),
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
    resources: BuildingResourceConfig(
      maintenanceCost: 70,
      electricityConsumption: 25,
      waterConsumption: 20,
      happinessBonus: 12,
      jobsProvided: 30,
      healthcareCapacity: 350,
    ),
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
    resources: BuildingResourceConfig(
      maintenanceCost: 45,
      electricityConsumption: 18,
      waterConsumption: 15,
      happinessBonus: 8,
      jobsProvided: 20,
      educationCapacity: 250,
    ),
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
    resources: BuildingResourceConfig(
      maintenanceCost: 25,
      electricityConsumption: 8,
      waterConsumption: 6,
      happinessBonus: 6,
      jobsProvided: 12,
      safetyCapacity: 300,
    ),
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
    resources: BuildingResourceConfig(
      maintenanceCost: 25,
      electricityConsumption: 8,
      waterConsumption: 6,
      happinessBonus: 6,
      jobsProvided: 12,
      safetyCapacity: 300,
    ),
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
    resources: BuildingResourceConfig(
      maintenanceCost: 1,
    ),
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
    resources: BuildingResourceConfig(
      electricityProduction: 250,
      maintenanceCost: 80,
      waterConsumption: 20,
      pollutionOutput: 15,
      jobsProvided: 15,
    ),
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
    resources: BuildingResourceConfig(
      waterProduction: 250,
      maintenanceCost: 60,
      electricityConsumption: 25,
      jobsProvided: 12,
    ),
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
    resources: BuildingResourceConfig(
      maintenanceCost: 15,
      waterConsumption: 10,
      pollutionReduction: 20,
      happinessBonus: 10,
      jobsProvided: 4,
    ),
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
    requiredPlayerLevel: 2,
    icon: Icons.yard_rounded,
    resources: BuildingResourceConfig(
      maintenanceCost: 8,
      waterConsumption: 5,
      pollutionReduction: 10,
      happinessBonus: 6,
      jobsProvided: 2,
    ),
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
    resources: BuildingResourceConfig(
      electricityProduction: 160,
      maintenanceCost: 35,
      pollutionReduction: 5,
      happinessBonus: 3,
      jobsProvided: 6,
    ),
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
    resources: BuildingResourceConfig(
      waterProduction: 140,
      maintenanceCost: 50,
      electricityConsumption: 30,
      pollutionReduction: 25,
      happinessBonus: 4,
      jobsProvided: 12,
    ),
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

  /// Alias for [get] to look up a building definition by its ID.
  static BuildingDefinition? findById(String typeId) => all[typeId];

  /// Lists all building definitions matching the given [category].
  static List<BuildingDefinition> byCategory(BuildingCategory category) {
    return all.values.where((b) => b.category == category).toList();
  }
}
