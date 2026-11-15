/// Comprehensive demographics and labor simulation data for the city.
class CityDemographics {
  const CityDemographics({
    this.totalPopulation = 0,
    this.housingCapacity = 0,
    this.totalJobs = 0,
    this.employedCount = 0,
    this.healthcareRating = 100,
    this.educationRating = 100,
    this.safetyRating = 100,
    this.housingDemand = 50,
    this.commercialDemand = 50,
    this.industrialDemand = 50,
    this.migrationRate = 0,
  });

  factory CityDemographics.initial() => const CityDemographics();

  factory CityDemographics.fromJson(Map<String, Object?> json) {
    return CityDemographics(
      totalPopulation: (json['totalPopulation'] as num?)?.toInt() ?? 0,
      housingCapacity: (json['housingCapacity'] as num?)?.toInt() ?? 0,
      totalJobs: (json['totalJobs'] as num?)?.toInt() ?? 0,
      employedCount: (json['employedCount'] as num?)?.toInt() ?? 0,
      healthcareRating: (json['healthcareRating'] as num?)?.toInt() ?? 100,
      educationRating: (json['educationRating'] as num?)?.toInt() ?? 100,
      safetyRating: (json['safetyRating'] as num?)?.toInt() ?? 100,
      housingDemand: (json['housingDemand'] as num?)?.toInt() ?? 50,
      commercialDemand: (json['commercialDemand'] as num?)?.toInt() ?? 50,
      industrialDemand: (json['industrialDemand'] as num?)?.toInt() ?? 50,
      migrationRate: (json['migrationRate'] as num?)?.toInt() ?? 0,
    );
  }

  /// Total living residents in the city.
  final int totalPopulation;

  /// Total housing capacity across all residential buildings.
  final int housingCapacity;

  /// Total jobs provided by commercial, industrial, and municipal buildings.
  final int totalJobs;

  /// Number of employed citizens.
  final int employedCount;

  /// Healthcare access rating (0 to 100).
  final int healthcareRating;

  /// Education accessibility rating (0 to 100).
  final int educationRating;

  /// Public safety rating (0 to 100).
  final int safetyRating;

  /// Demand index for new residential housing (-100 to 100).
  final int housingDemand;

  /// Demand index for commercial retail and offices (-100 to 100).
  final int commercialDemand;

  /// Demand index for manufacturing and factories (-100 to 100).
  final int industrialDemand;

  /// Net population change on the latest simulation tick.
  final int migrationRate;

  /// Housing occupancy percentage (0 to 100).
  int get occupancyRate {
    if (housingCapacity <= 0) return 0;
    return ((totalPopulation / housingCapacity) * 100).clamp(0, 100).round();
  }

  /// Estimated working-age citizens (~65% of population).
  int get workingAgePopulation => (totalPopulation * 0.65).round();

  /// Employment percentage among working-age citizens (0 to 100).
  int get employmentRate {
    final workers = workingAgePopulation;
    if (workers <= 0) return 100;
    return ((employedCount / workers) * 100).clamp(0, 100).round();
  }

  /// Unfilled job vacancies in the city.
  int get vacantJobs => totalJobs > employedCount ? totalJobs - employedCount : 0;

  /// Unemployed citizens seeking work.
  int get unemployedCount {
    final workers = workingAgePopulation;
    return workers > employedCount ? workers - employedCount : 0;
  }

  CityDemographics copyWith({
    int? totalPopulation,
    int? housingCapacity,
    int? totalJobs,
    int? employedCount,
    int? healthcareRating,
    int? educationRating,
    int? safetyRating,
    int? housingDemand,
    int? commercialDemand,
    int? industrialDemand,
    int? migrationRate,
  }) {
    return CityDemographics(
      totalPopulation: totalPopulation ?? this.totalPopulation,
      housingCapacity: housingCapacity ?? this.housingCapacity,
      totalJobs: totalJobs ?? this.totalJobs,
      employedCount: employedCount ?? this.employedCount,
      healthcareRating: healthcareRating ?? this.healthcareRating,
      educationRating: educationRating ?? this.educationRating,
      safetyRating: safetyRating ?? this.safetyRating,
      housingDemand: housingDemand ?? this.housingDemand,
      commercialDemand: commercialDemand ?? this.commercialDemand,
      industrialDemand: industrialDemand ?? this.industrialDemand,
      migrationRate: migrationRate ?? this.migrationRate,
    );
  }

  Map<String, Object?> toJson() => {
        'totalPopulation': totalPopulation,
        'housingCapacity': housingCapacity,
        'totalJobs': totalJobs,
        'employedCount': employedCount,
        'healthcareRating': healthcareRating,
        'educationRating': educationRating,
        'safetyRating': safetyRating,
        'housingDemand': housingDemand,
        'commercialDemand': commercialDemand,
        'industrialDemand': industrialDemand,
        'migrationRate': migrationRate,
      };
}
