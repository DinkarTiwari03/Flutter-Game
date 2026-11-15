import 'package:city_builder_2040/core/constants/game_constants.dart';

/// Stockpile of a city's resources, keyed by stable resource id
/// (for example `coins`, `population`, `happiness`, `pollution`).
class ResourceLedger {
  ResourceLedger({
    required this.cityId,
    required Map<String, double> amounts,
    required this.updatedAt,
  }) : amounts = Map.unmodifiable(amounts);

  factory ResourceLedger.fromJson(Map<String, Object?> json) {
    final raw = json['amounts'] as Map;
    return ResourceLedger(
      cityId: json['cityId'] as String,
      amounts: raw.map(
        (key, value) => MapEntry(key as String, (value as num).toDouble()),
      ),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Initial resource ledger for a newly founded city.
  factory ResourceLedger.initial(
    String cityId, {
    int startingCoins = GameConstants.startingCoins,
    int startingHappiness = GameConstants.startingHappiness,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    return ResourceLedger(
      cityId: cityId,
      amounts: {
        coinsKey: startingCoins.toDouble(),
        populationKey: 0.0,
        happinessKey: startingHappiness.toDouble(),
        pollutionKey: 0.0,
      },
      updatedAt: timestamp,
    );
  }

  static const String coinsKey = 'coins';
  static const String populationKey = 'population';
  static const String happinessKey = 'happiness';
  static const String pollutionKey = 'pollution';

  final String cityId;
  final Map<String, double> amounts;
  final DateTime updatedAt;

  double amountOf(String resourceId) => amounts[resourceId] ?? 0;

  int get coins => (amounts[coinsKey] ?? 0).round();
  int get population => (amounts[populationKey] ?? 0).round();
  int get happiness => (amounts[happinessKey] ?? 0).round();
  int get pollution => (amounts[pollutionKey] ?? 0).round();

  ResourceLedger copyWith({
    Map<String, double>? amounts,
    DateTime? updatedAt,
  }) {
    return ResourceLedger(
      cityId: cityId,
      amounts: amounts ?? this.amounts,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Returns a copy of this ledger with updated resource amounts.
  ResourceLedger updateAmounts(
    Map<String, double> newAmounts, {
    DateTime? updatedAt,
  }) {
    final merged = Map<String, double>.from(amounts)..addAll(newAmounts);
    return ResourceLedger(
      cityId: cityId,
      amounts: merged,
      updatedAt: (updatedAt ?? DateTime.now()).toUtc(),
    );
  }

  Map<String, Object?> toJson() => {
    'cityId': cityId,
    'amounts': amounts,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
