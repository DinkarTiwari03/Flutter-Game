/// Core resources available in City Builder 2040.
enum CityResourceType {
  coins('Coins', '¢'),
  population('Population', 'pop'),
  electricity('Electricity', 'kW'),
  water('Water', 'kL'),
  happiness('Happiness', '%'),
  pollution('Pollution', '%');

  const CityResourceType(this.label, this.unit);

  final String label;
  final String unit;
}

/// Balance of a utility resource (electricity or water) showing production,
/// consumption, and the resulting satisfaction percentage.
class UtilityBalance {
  const UtilityBalance({
    required this.production,
    required this.consumption,
  });

  final int production;
  final int consumption;

  /// Net balance: positive represents surplus, negative represents deficit.
  int get net => production - consumption;

  /// Whether production meets or exceeds consumption.
  bool get isDeficit => consumption > 0 && production < consumption;

  /// Satisfaction percentage (0 to 100).
  /// If consumption is 0, satisfaction is 100%.
  int get satisfactionRate {
    if (consumption <= 0) return 100;
    if (production <= 0) return 0;
    final rate = (production / consumption) * 100.0;
    return rate.clamp(0, 100).round();
  }
}

/// Detailed breakdown of city income sources per simulation tick.
class IncomeBreakdown {
  const IncomeBreakdown({
    this.residentialTaxes = 0,
    this.commercialIncome = 0,
    this.industrialIncome = 0,
    this.otherIncome = 0,
  });

  final int residentialTaxes;
  final int commercialIncome;
  final int industrialIncome;
  final int otherIncome;

  int get total =>
      residentialTaxes + commercialIncome + industrialIncome + otherIncome;
}

/// Detailed breakdown of city operating expenses per simulation tick.
class ExpenseBreakdown {
  const ExpenseBreakdown({
    this.buildingMaintenance = 0,
    this.roadMaintenance = 0,
    this.electricityProductionCost = 0,
    this.waterProductionCost = 0,
  });

  final int buildingMaintenance;
  final int roadMaintenance;
  final int electricityProductionCost;
  final int waterProductionCost;

  int get total =>
      buildingMaintenance +
      roadMaintenance +
      electricityProductionCost +
      waterProductionCost;
}

/// Comprehensive summary of the city's financial cashflow.
class CashflowSummary {
  const CashflowSummary({
    required this.income,
    required this.expenses,
  });

  final IncomeBreakdown income;
  final ExpenseBreakdown expenses;

  int get net => income.total - expenses.total;
  bool get isDeficit => net < 0;
}

/// High-level evaluation of city health and warning states.
class ResourceWarnings {
  const ResourceWarnings({
    this.lowCoins = false,
    this.electricityDeficit = false,
    this.waterDeficit = false,
    this.lowHappiness = false,
    this.highPollution = false,
    this.noHousing = false,
  });

  final bool lowCoins;
  final bool electricityDeficit;
  final bool waterDeficit;
  final bool lowHappiness;
  final bool highPollution;
  final bool noHousing;

  bool get hasAny =>
      lowCoins ||
      electricityDeficit ||
      waterDeficit ||
      lowHappiness ||
      highPollution ||
      noHousing;
}

/// Complete immutable snapshot of the city's economy and resource states.
class CityResourcesSnapshot {
  const CityResourcesSnapshot({
    required this.coins,
    required this.population,
    required this.housingCapacity,
    required this.electricity,
    required this.water,
    required this.happiness,
    required this.pollution,
    required this.cashflow,
    required this.warnings,
    required this.level,
    required this.timestamp,
  });

  final int coins;
  final int population;
  final int housingCapacity;
  final UtilityBalance electricity;
  final UtilityBalance water;

  /// Citizen happiness rating from 0 to 100.
  final int happiness;

  /// Environmental pollution index from 0 to 100.
  final int pollution;

  final CashflowSummary cashflow;
  final ResourceWarnings warnings;
  final int level;
  final DateTime timestamp;

  /// Population occupancy percentage (0 to 100).
  int get occupancyRate {
    if (housingCapacity <= 0) return 0;
    return ((population / housingCapacity) * 100).clamp(0, 100).round();
  }
}
