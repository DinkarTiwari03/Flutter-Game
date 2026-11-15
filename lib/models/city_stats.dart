import 'package:city_builder_2040/core/constants/game_constants.dart';
import 'package:city_builder_2040/models/city.dart';
import 'package:city_builder_2040/models/city_resource.dart';

/// Headline numbers shown in the game HUD and dashboard.
class CityStats {
  const CityStats({
    required this.coins,
    required this.population,
    required this.happiness,
    this.electricity = 100,
    this.water = 100,
    this.level = 1,
    this.pollution = 0,
    this.housingCapacity = 0,
    this.netIncome = 0,
    this.electricityProduced = 0,
    this.electricityConsumed = 0,
    this.waterProduced = 0,
    this.waterConsumed = 0,
  });

  factory CityStats.initial(City city) => CityStats(
    coins: GameConstants.startingCoins,
    population: city.population,
    happiness: GameConstants.startingHappiness,
    electricity: 100,
    water: 100,
    level: 1,
    pollution: 0,
    housingCapacity: 0,
    netIncome: 0,
    electricityProduced: 0,
    electricityConsumed: 0,
    waterProduced: 0,
    waterConsumed: 0,
  );

  factory CityStats.fromSnapshot(CityResourcesSnapshot snapshot) {
    return CityStats(
      coins: snapshot.coins,
      population: snapshot.population,
      happiness: snapshot.happiness,
      electricity: snapshot.electricity.satisfactionRate,
      water: snapshot.water.satisfactionRate,
      level: snapshot.level,
      pollution: snapshot.pollution,
      housingCapacity: snapshot.housingCapacity,
      netIncome: snapshot.cashflow.net,
      electricityProduced: snapshot.electricity.production,
      electricityConsumed: snapshot.electricity.consumption,
      waterProduced: snapshot.water.production,
      waterConsumed: snapshot.water.consumption,
    );
  }

  final int coins;
  final int population;

  /// Percentage from 0 to 100.
  final int happiness;

  /// Percentage supply from 0 to 100.
  final int electricity;

  /// Percentage supply from 0 to 100.
  final int water;

  /// City development level.
  final int level;

  /// Pollution percentage from 0 to 100.
  final int pollution;

  /// Total housing capacity provided by residential buildings.
  final int housingCapacity;

  /// Net income per simulation tick (positive = profit, negative = loss).
  final int netIncome;

  final int electricityProduced;
  final int electricityConsumed;
  final int waterProduced;
  final int waterConsumed;

  // Warning thresholds
  bool get isLowCoins => coins < 500;
  bool get isElectricityDeficit => electricity < 100;
  bool get isWaterDeficit => water < 100;
  bool get isUnhappy => happiness < 50;
  bool get isPolluted => pollution >= 50;
}
