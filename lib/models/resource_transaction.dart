/// Types of resource transactions tracked in the city economy.
enum TransactionType {
  construction('Construction'),
  upgrade('Upgrade'),
  demolitionRefund('Demolition Refund'),
  residentialTax('Residential Taxes'),
  commercialIncome('Commercial Income'),
  industrialIncome('Industrial Income'),
  maintenanceExpense('Maintenance Upkeep'),
  utilityCost('Utility Costs');

  const TransactionType(this.label);

  final String label;
}

/// Immutable record of an important financial or resource event.
class ResourceTransaction {
  const ResourceTransaction({
    required this.id,
    required this.cityId,
    required this.type,
    required this.amount,
    required this.description,
    required this.timestamp,
    this.buildingId,
    this.buildingTypeId,
  });

  factory ResourceTransaction.fromJson(Map<String, Object?> json) {
    return ResourceTransaction(
      id: json['id'] as String,
      cityId: json['cityId'] as String,
      type: TransactionType.values.byName(json['type'] as String),
      amount: (json['amount'] as num).toInt(),
      description: json['description'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      buildingId: json['buildingId'] as String?,
      buildingTypeId: json['buildingTypeId'] as String?,
    );
  }

  final String id;
  final String cityId;
  final TransactionType type;

  /// Amount in coins. Positive represents income or refunds; negative represents
  /// expenses or deductions.
  final int amount;

  final String description;
  final DateTime timestamp;
  final String? buildingId;
  final String? buildingTypeId;

  bool get isIncome => amount > 0;
  bool get isExpense => amount < 0;

  Map<String, Object?> toJson() => {
    'id': id,
    'cityId': cityId,
    'type': type.name,
    'amount': amount,
    'description': description,
    'timestamp': timestamp.toUtc().toIso8601String(),
    if (buildingId != null) 'buildingId': buildingId,
    if (buildingTypeId != null) 'buildingTypeId': buildingTypeId,
  };
}
