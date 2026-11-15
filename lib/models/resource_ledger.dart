/// Stockpile of a city's resources, keyed by stable resource id
/// (for example `money`, `power`, `water`).
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

  final String cityId;
  final Map<String, double> amounts;
  final DateTime updatedAt;

  double amountOf(String resourceId) => amounts[resourceId] ?? 0;

  ResourceLedger copyWith({Map<String, double>? amounts, DateTime? updatedAt}) {
    return ResourceLedger(
      cityId: cityId,
      amounts: amounts ?? this.amounts,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
    'cityId': cityId,
    'amounts': amounts,
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };
}
