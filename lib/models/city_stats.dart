import 'package:city_builder_2040/core/constants/game_constants.dart';
import 'package:city_builder_2040/models/city.dart';

/// Headline numbers shown in the game HUD.
///
/// Phase 2 displays starting and placeholder values; the simulation that
/// changes them arrives in a later phase.
class CityStats {
  const CityStats({
    required this.coins,
    required this.population,
    required this.happiness,
    this.electricity = 100,
    this.water = 100,
    this.level = 1,
  });

  factory CityStats.initial(City city) => CityStats(
    coins: GameConstants.startingCoins,
    population: city.population,
    happiness: GameConstants.startingHappiness,
    electricity: 100,
    water: 100,
    level: 1,
  );

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
}
