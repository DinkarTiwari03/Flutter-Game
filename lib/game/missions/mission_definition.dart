// Mission definitions - static game content, never persisted.
// Only MissionProgress (lib/models/mission_progress.dart) is persisted.

enum MissionCategory {
  construction('Construction', '🏗️'),
  population('Population', '👥'),
  economy('Economy', '💰'),
  sustainability('Sustainability', '🌿');

  const MissionCategory(this.label, this.emoji);
  final String label;
  final String emoji;
}

enum ObjectiveType {
  buildCount, // total buildings placed
  buildingTypeCount, // specific typeId placed
  buildingCategoryCount, // buildings of a category placed
  reachPopulation,
  reachHousingCapacity,
  reachCoins,
  maintainPositiveIncome, // net income > 0
  reducePollution, // pollution <= targetValue
  buildParkCount,
  reachHappiness,
  generateRenewableEnergy, // electricityProduction from solar_plant >= targetValue
  improveEmployment, // employmentRate >= targetValue
}

class MissionObjective {
  const MissionObjective({
    required this.type,
    required this.targetValue,
    required this.description,
    this.buildingTypeId,
    this.buildingCategoryId,
  });

  final ObjectiveType type;
  final double targetValue;
  final String description;
  final String? buildingTypeId;
  final String? buildingCategoryId;
}

enum MissionDifficulty { beginner, intermediate, advanced }

class MissionReward {
  const MissionReward({
    this.coins = 0,
    this.xp = 0,
    this.unlockedBuildingIds = const [],
    this.unlockedDecorationIds = const [],
  });

  final int coins;
  final int xp;
  final List<String> unlockedBuildingIds;
  final List<String> unlockedDecorationIds;
}

class MissionDefinition {
  const MissionDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.difficulty,
    required this.objectives,
    required this.reward,
    this.prerequisiteMissionIds = const [],
    this.isChallenge = false,
  });

  final String id;
  final String title;
  final String description;
  final MissionCategory category;
  final MissionDifficulty difficulty;
  final List<MissionObjective> objectives;
  final MissionReward reward;
  final List<String> prerequisiteMissionIds;
  final bool isChallenge;
}

/// All mission definitions in the game. Definitions are immutable game content.
class MissionRegistry {
  MissionRegistry._();

  static const List<MissionDefinition> all = [
    // ───────────── CONSTRUCTION ─────────────
    MissionDefinition(
      id: 'first_home',
      title: 'First Home',
      description: 'Build your first residential building to welcome citizens.',
      category: MissionCategory.construction,
      difficulty: MissionDifficulty.beginner,
      objectives: [
        MissionObjective(
          type: ObjectiveType.buildingCategoryCount,
          targetValue: 1,
          description: 'Build 1 residential building',
          buildingCategoryId: 'residential',
        ),
      ],
      reward: MissionReward(coins: 200, xp: 50),
    ),
    MissionDefinition(
      id: 'housing_expansion',
      title: 'Housing Expansion',
      description: 'Build 5 residential buildings to house growing population.',
      category: MissionCategory.construction,
      difficulty: MissionDifficulty.beginner,
      objectives: [
        MissionObjective(
          type: ObjectiveType.buildingCategoryCount,
          targetValue: 5,
          description: 'Build 5 residential buildings',
          buildingCategoryId: 'residential',
        ),
      ],
      reward: MissionReward(coins: 500, xp: 100),
      prerequisiteMissionIds: ['first_home'],
    ),
    MissionDefinition(
      id: 'housing_district',
      title: 'Housing District',
      description: 'Build 15 residential buildings and create a true neighborhood.',
      category: MissionCategory.construction,
      difficulty: MissionDifficulty.intermediate,
      objectives: [
        MissionObjective(
          type: ObjectiveType.buildingCategoryCount,
          targetValue: 15,
          description: 'Build 15 residential buildings',
          buildingCategoryId: 'residential',
        ),
      ],
      reward: MissionReward(coins: 1500, xp: 250),
      prerequisiteMissionIds: ['housing_expansion'],
    ),
    MissionDefinition(
      id: 'first_shop',
      title: 'Open for Business',
      description: 'Build a commercial building to kickstart the local economy.',
      category: MissionCategory.construction,
      difficulty: MissionDifficulty.beginner,
      objectives: [
        MissionObjective(
          type: ObjectiveType.buildingCategoryCount,
          targetValue: 1,
          description: 'Build 1 commercial building',
          buildingCategoryId: 'commercial',
        ),
      ],
      reward: MissionReward(coins: 300, xp: 50),
    ),
    MissionDefinition(
      id: 'commercial_hub',
      title: 'Commercial Hub',
      description: 'Build 5 commercial buildings to establish a thriving business district.',
      category: MissionCategory.construction,
      difficulty: MissionDifficulty.intermediate,
      objectives: [
        MissionObjective(
          type: ObjectiveType.buildingCategoryCount,
          targetValue: 5,
          description: 'Build 5 commercial buildings',
          buildingCategoryId: 'commercial',
        ),
      ],
      reward: MissionReward(coins: 1000, xp: 150),
      prerequisiteMissionIds: ['first_shop'],
    ),
    MissionDefinition(
      id: 'public_service_start',
      title: 'Public Services',
      description: 'Build a hospital or school to serve your citizens.',
      category: MissionCategory.construction,
      difficulty: MissionDifficulty.beginner,
      objectives: [
        MissionObjective(
          type: ObjectiveType.buildingCategoryCount,
          targetValue: 1,
          description: 'Build 1 public service building',
          buildingCategoryId: 'publicServices',
        ),
      ],
      reward: MissionReward(coins: 400, xp: 75),
    ),
    MissionDefinition(
      id: 'city_services',
      title: 'Full City Services',
      description: 'Build a hospital, school, police station, and fire station.',
      category: MissionCategory.construction,
      difficulty: MissionDifficulty.intermediate,
      objectives: [
        MissionObjective(
          type: ObjectiveType.buildingTypeCount,
          targetValue: 1,
          description: 'Build a hospital',
          buildingTypeId: 'hospital',
        ),
        MissionObjective(
          type: ObjectiveType.buildingTypeCount,
          targetValue: 1,
          description: 'Build a school',
          buildingTypeId: 'school',
        ),
        MissionObjective(
          type: ObjectiveType.buildingTypeCount,
          targetValue: 1,
          description: 'Build a police station',
          buildingTypeId: 'police_station',
        ),
        MissionObjective(
          type: ObjectiveType.buildingTypeCount,
          targetValue: 1,
          description: 'Build a fire station',
          buildingTypeId: 'fire_station',
        ),
      ],
      reward: MissionReward(coins: 2000, xp: 350),
      prerequisiteMissionIds: ['public_service_start'],
    ),
    MissionDefinition(
      id: 'city_builder',
      title: 'City Builder',
      description: 'Have 20 or more buildings in your city.',
      category: MissionCategory.construction,
      difficulty: MissionDifficulty.advanced,
      objectives: [
        MissionObjective(
          type: ObjectiveType.buildCount,
          targetValue: 20,
          description: 'Build 20 total buildings',
        ),
      ],
      reward: MissionReward(coins: 3000, xp: 500),
      prerequisiteMissionIds: ['housing_district'],
    ),

    // ───────────── POPULATION ─────────────
    MissionDefinition(
      id: 'first_citizens',
      title: 'First Citizens',
      description: 'Grow your city population to 50 residents.',
      category: MissionCategory.population,
      difficulty: MissionDifficulty.beginner,
      objectives: [
        MissionObjective(
          type: ObjectiveType.reachPopulation,
          targetValue: 50,
          description: 'Reach 50 population',
        ),
      ],
      reward: MissionReward(coins: 300, xp: 75),
    ),
    MissionDefinition(
      id: 'growing_town',
      title: 'Growing Town',
      description: 'Grow your population to 200 residents.',
      category: MissionCategory.population,
      difficulty: MissionDifficulty.beginner,
      objectives: [
        MissionObjective(
          type: ObjectiveType.reachPopulation,
          targetValue: 200,
          description: 'Reach 200 population',
        ),
      ],
      reward: MissionReward(coins: 800, xp: 150),
      prerequisiteMissionIds: ['first_citizens'],
    ),
    MissionDefinition(
      id: 'bustling_city',
      title: 'Bustling City',
      description: 'Grow your population to 1000 residents.',
      category: MissionCategory.population,
      difficulty: MissionDifficulty.intermediate,
      objectives: [
        MissionObjective(
          type: ObjectiveType.reachPopulation,
          targetValue: 1000,
          description: 'Reach 1000 population',
        ),
      ],
      reward: MissionReward(coins: 2500, xp: 400),
      prerequisiteMissionIds: ['growing_town'],
    ),
    MissionDefinition(
      id: 'housing_capacity_250',
      title: 'Housing for All',
      description: 'Provide 250 housing capacity for your growing population.',
      category: MissionCategory.population,
      difficulty: MissionDifficulty.beginner,
      objectives: [
        MissionObjective(
          type: ObjectiveType.reachHousingCapacity,
          targetValue: 250,
          description: 'Provide 250 housing capacity',
        ),
      ],
      reward: MissionReward(coins: 500, xp: 100),
    ),
    MissionDefinition(
      id: 'full_employment',
      title: 'Full Employment',
      description: 'Achieve 80% employment rate across the city.',
      category: MissionCategory.population,
      difficulty: MissionDifficulty.intermediate,
      objectives: [
        MissionObjective(
          type: ObjectiveType.improveEmployment,
          targetValue: 80,
          description: 'Reach 80% employment rate',
        ),
      ],
      reward: MissionReward(coins: 1500, xp: 300),
      prerequisiteMissionIds: ['first_citizens'],
    ),

    // ───────────── ECONOMY ─────────────
    MissionDefinition(
      id: 'first_thousand',
      title: 'First Thousand',
      description: 'Accumulate 1,000 coins in the city treasury.',
      category: MissionCategory.economy,
      difficulty: MissionDifficulty.beginner,
      objectives: [
        MissionObjective(
          type: ObjectiveType.reachCoins,
          targetValue: 1000,
          description: 'Have 1,000 coins',
        ),
      ],
      reward: MissionReward(coins: 300, xp: 50),
    ),
    MissionDefinition(
      id: 'prosperous_city',
      title: 'Prosperous City',
      description: 'Accumulate 10,000 coins in the city treasury.',
      category: MissionCategory.economy,
      difficulty: MissionDifficulty.intermediate,
      objectives: [
        MissionObjective(
          type: ObjectiveType.reachCoins,
          targetValue: 10000,
          description: 'Have 10,000 coins',
        ),
      ],
      reward: MissionReward(coins: 1000, xp: 250),
      prerequisiteMissionIds: ['first_thousand'],
    ),
    MissionDefinition(
      id: 'positive_cashflow',
      title: 'Positive Cashflow',
      description: 'Ensure your city has a positive income balance.',
      category: MissionCategory.economy,
      difficulty: MissionDifficulty.beginner,
      objectives: [
        MissionObjective(
          type: ObjectiveType.maintainPositiveIncome,
          targetValue: 1,
          description: 'Maintain positive net income',
        ),
      ],
      reward: MissionReward(coins: 500, xp: 100),
    ),
    MissionDefinition(
      id: 'wealthy_metropolis',
      title: 'Wealthy Metropolis',
      description: 'Accumulate 50,000 coins in the city treasury.',
      category: MissionCategory.economy,
      difficulty: MissionDifficulty.advanced,
      objectives: [
        MissionObjective(
          type: ObjectiveType.reachCoins,
          targetValue: 50000,
          description: 'Have 50,000 coins',
        ),
      ],
      reward: MissionReward(coins: 5000, xp: 750),
      prerequisiteMissionIds: ['prosperous_city'],
    ),

    // ───────────── SUSTAINABILITY ─────────────
    MissionDefinition(
      id: 'first_park',
      title: 'Green Space',
      description: 'Build a park to provide citizens with outdoor recreation.',
      category: MissionCategory.sustainability,
      difficulty: MissionDifficulty.beginner,
      objectives: [
        MissionObjective(
          type: ObjectiveType.buildParkCount,
          targetValue: 1,
          description: 'Build 1 park or garden',
        ),
      ],
      reward: MissionReward(coins: 200, xp: 50),
    ),
    MissionDefinition(
      id: 'park_network',
      title: 'Park Network',
      description: 'Build 5 parks or gardens for a greener city.',
      category: MissionCategory.sustainability,
      difficulty: MissionDifficulty.beginner,
      objectives: [
        MissionObjective(
          type: ObjectiveType.buildParkCount,
          targetValue: 5,
          description: 'Build 5 parks or gardens',
        ),
      ],
      reward: MissionReward(coins: 800, xp: 150),
      prerequisiteMissionIds: ['first_park'],
    ),
    MissionDefinition(
      id: 'solar_power',
      title: 'Solar Power',
      description: 'Build a solar plant to generate renewable electricity.',
      category: MissionCategory.sustainability,
      difficulty: MissionDifficulty.beginner,
      objectives: [
        MissionObjective(
          type: ObjectiveType.buildingTypeCount,
          targetValue: 1,
          description: 'Build 1 solar plant',
          buildingTypeId: 'solar_plant',
        ),
      ],
      reward: MissionReward(coins: 400, xp: 75),
    ),
    MissionDefinition(
      id: 'renewable_city',
      title: 'Renewable City',
      description: 'Generate at least 100kW from solar plants.',
      category: MissionCategory.sustainability,
      difficulty: MissionDifficulty.intermediate,
      objectives: [
        MissionObjective(
          type: ObjectiveType.generateRenewableEnergy,
          targetValue: 100,
          description: 'Generate 100kW from solar plants',
        ),
      ],
      reward: MissionReward(coins: 1500, xp: 300),
      prerequisiteMissionIds: ['solar_power'],
    ),
    MissionDefinition(
      id: 'clean_air',
      title: 'Clean Air Initiative',
      description: 'Reduce city pollution to 30 or below.',
      category: MissionCategory.sustainability,
      difficulty: MissionDifficulty.intermediate,
      objectives: [
        MissionObjective(
          type: ObjectiveType.reducePollution,
          targetValue: 30,
          description: 'Reduce pollution to 30 or less',
        ),
      ],
      reward: MissionReward(coins: 1200, xp: 250),
      prerequisiteMissionIds: ['first_park'],
    ),
    MissionDefinition(
      id: 'happy_citizens',
      title: 'Happy Citizens',
      description: 'Achieve a city happiness rating of 70%.',
      category: MissionCategory.sustainability,
      difficulty: MissionDifficulty.intermediate,
      objectives: [
        MissionObjective(
          type: ObjectiveType.reachHappiness,
          targetValue: 70,
          description: 'Reach 70% happiness rating',
        ),
      ],
      reward: MissionReward(coins: 1000, xp: 200),
    ),

    // ───────────── CHALLENGES ─────────────
    MissionDefinition(
      id: 'challenge_quick_build',
      title: 'Quick Builder',
      description: 'Build 3 buildings to get started fast.',
      category: MissionCategory.construction,
      difficulty: MissionDifficulty.beginner,
      objectives: [
        MissionObjective(
          type: ObjectiveType.buildCount,
          targetValue: 3,
          description: 'Build 3 buildings',
        ),
      ],
      reward: MissionReward(coins: 150, xp: 30),
      isChallenge: true,
    ),
    MissionDefinition(
      id: 'challenge_power_on',
      title: 'Power On',
      description: 'Build 2 power infrastructure buildings.',
      category: MissionCategory.sustainability,
      difficulty: MissionDifficulty.beginner,
      objectives: [
        MissionObjective(
          type: ObjectiveType.buildingCategoryCount,
          targetValue: 2,
          description: 'Build 2 infrastructure buildings',
          buildingCategoryId: 'infrastructure',
        ),
      ],
      reward: MissionReward(coins: 250, xp: 50),
      isChallenge: true,
    ),
    MissionDefinition(
      id: 'challenge_eco_start',
      title: 'Eco Start',
      description: 'Build 2 environment buildings.',
      category: MissionCategory.sustainability,
      difficulty: MissionDifficulty.beginner,
      objectives: [
        MissionObjective(
          type: ObjectiveType.buildingCategoryCount,
          targetValue: 2,
          description: 'Build 2 environment buildings',
          buildingCategoryId: 'environment',
        ),
      ],
      reward: MissionReward(coins: 200, xp: 40),
      isChallenge: true,
    ),
    MissionDefinition(
      id: 'challenge_population_boost',
      title: 'Population Boost',
      description: 'Grow your city to 100 citizens.',
      category: MissionCategory.population,
      difficulty: MissionDifficulty.intermediate,
      objectives: [
        MissionObjective(
          type: ObjectiveType.reachPopulation,
          targetValue: 100,
          description: 'Reach 100 citizens',
        ),
      ],
      reward: MissionReward(coins: 500, xp: 100),
      isChallenge: true,
    ),
    MissionDefinition(
      id: 'challenge_economic_milestone',
      title: 'Economic Milestone',
      description: 'Build a commercial district with 3 commercial buildings.',
      category: MissionCategory.economy,
      difficulty: MissionDifficulty.intermediate,
      objectives: [
        MissionObjective(
          type: ObjectiveType.buildingCategoryCount,
          targetValue: 3,
          description: 'Build 3 commercial buildings',
          buildingCategoryId: 'commercial',
        ),
      ],
      reward: MissionReward(coins: 750, xp: 150),
      isChallenge: true,
    ),
  ];

  static List<MissionDefinition> get missions =>
      all.where((m) => !m.isChallenge).toList();

  static List<MissionDefinition> get challenges =>
      all.where((m) => m.isChallenge).toList();

  static MissionDefinition? findById(String id) {
    try {
      return all.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }
}
