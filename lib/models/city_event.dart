import 'package:flutter/material.dart';

/// Categories of positive civic events in City Builder 2040.
enum CityEventType {
  populationGrowthBonus('Population Boom', Icons.groups_rounded),
  taxIncomeBonus('Economic Prosperity', Icons.trending_up_rounded),
  sustainabilityReward('Sustainability Grant', Icons.eco_rounded),
  happinessBonus('Civic Festival', Icons.celebration_rounded);

  const CityEventType(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// A positive timed civic event with clear duration and mechanical bonuses.
class CityEvent {
  const CityEvent({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.durationTicks,
    required this.remainingTicks,
    this.multiplier = 1.0,
    this.happinessModifier = 0,
    this.pollutionModifier = 0,
    this.instantCoinReward = 0,
  });

  factory CityEvent.fromJson(Map<String, Object?> json) {
    return CityEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      type: CityEventType.values.byName(json['type'] as String),
      durationTicks: (json['durationTicks'] as num).toInt(),
      remainingTicks: (json['remainingTicks'] as num).toInt(),
      multiplier: (json['multiplier'] as num?)?.toDouble() ?? 1.0,
      happinessModifier: (json['happinessModifier'] as num?)?.toInt() ?? 0,
      pollutionModifier: (json['pollutionModifier'] as num?)?.toInt() ?? 0,
      instantCoinReward: (json['instantCoinReward'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String title;
  final String description;
  final CityEventType type;

  /// Total duration in simulation ticks.
  final int durationTicks;

  /// Remaining ticks until expiration.
  final int remainingTicks;

  /// Multiplier for income or growth (e.g. 1.25 = +25%).
  final double multiplier;

  /// Additive bonus applied to happiness.
  final int happinessModifier;

  /// Reduction applied to city pollution.
  final int pollutionModifier;

  /// One-time grant added to treasury when triggered.
  final int instantCoinReward;

  bool get isExpired => remainingTicks <= 0;

  /// Remaining in-game hours (1 tick = 1 in-game hour).
  int get remainingHours => remainingTicks;

  /// Decrements remaining duration by 1 tick.
  CityEvent tick() => copyWith(remainingTicks: remainingTicks - 1);

  CityEvent copyWith({
    int? remainingTicks,
  }) {
    return CityEvent(
      id: id,
      title: title,
      description: description,
      type: type,
      durationTicks: durationTicks,
      remainingTicks: remainingTicks ?? this.remainingTicks,
      multiplier: multiplier,
      happinessModifier: happinessModifier,
      pollutionModifier: pollutionModifier,
      instantCoinReward: instantCoinReward,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'type': type.name,
        'durationTicks': durationTicks,
        'remainingTicks': remainingTicks,
        'multiplier': multiplier,
        'happinessModifier': happinessModifier,
        'pollutionModifier': pollutionModifier,
        'instantCoinReward': instantCoinReward,
      };
}

/// Standard pool of positive city events for V1.
abstract final class CityEventPool {
  static const techBoom = CityEvent(
    id: 'event_tech_boom',
    title: 'Tech Innovation Surge',
    description: 'High-tech investments increase commercial revenues by 25%.',
    type: CityEventType.taxIncomeBonus,
    durationTicks: 12,
    remainingTicks: 12,
    multiplier: 1.25,
  );

  static const babyBoom = CityEvent(
    id: 'event_baby_boom',
    title: 'Migration & Family Boom',
    description: 'New families arrive! Population growth rate increases by 50%.',
    type: CityEventType.populationGrowthBonus,
    durationTicks: 14,
    remainingTicks: 14,
    multiplier: 1.5,
  );

  static const greenGrant = CityEvent(
    id: 'event_green_grant',
    title: 'Green City Sustainability Award',
    description: 'Environmental recognition grants ¢2,000 and reduces pollution.',
    type: CityEventType.sustainabilityReward,
    durationTicks: 10,
    remainingTicks: 10,
    pollutionModifier: -10,
    instantCoinReward: 2000,
  );

  static const civicFestival = CityEvent(
    id: 'event_civic_festival',
    title: 'Annual City Carnival',
    description: 'Joyful community celebrations boost city happiness by +12%.',
    type: CityEventType.happinessBonus,
    durationTicks: 10,
    remainingTicks: 10,
    happinessModifier: 12,
  );

  static final List<CityEvent> all = [
    techBoom,
    babyBoom,
    greenGrant,
    civicFestival,
  ];
}

