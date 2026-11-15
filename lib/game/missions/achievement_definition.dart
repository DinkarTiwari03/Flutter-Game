import 'package:city_builder_2040/game/missions/mission_definition.dart';

class AchievementDefinition {
  const AchievementDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.reward,
    required this.objective,
  });

  final String id;
  final String title;
  final String description;
  final String icon; // emoji icon
  final MissionReward reward;
  final MissionObjective objective;
}

class AchievementRegistry {
  AchievementRegistry._();

  static const List<AchievementDefinition> all = [
    AchievementDefinition(
      id: 'ach_first_build',
      title: 'The Beginning',
      description: 'Place your very first building.',
      icon: '🏛️',
      reward: MissionReward(xp: 25),
      objective: MissionObjective(
        type: ObjectiveType.buildCount,
        targetValue: 1,
        description: 'Build 1 building',
      ),
    ),
    AchievementDefinition(
      id: 'ach_10_buildings',
      title: 'Urban Planner',
      description: 'Have 10 buildings in your city.',
      icon: '🏙️',
      reward: MissionReward(xp: 75),
      objective: MissionObjective(
        type: ObjectiveType.buildCount,
        targetValue: 10,
        description: 'Build 10 buildings',
      ),
    ),
    AchievementDefinition(
      id: 'ach_25_buildings',
      title: 'Master Builder',
      description: 'Have 25 buildings in your city.',
      icon: '🏗️',
      reward: MissionReward(xp: 200, coins: 1000),
      objective: MissionObjective(
        type: ObjectiveType.buildCount,
        targetValue: 25,
        description: 'Build 25 buildings',
      ),
    ),
    AchievementDefinition(
      id: 'ach_population_100',
      title: 'Century Mark',
      description: 'Reach a population of 100 citizens.',
      icon: '🎉',
      reward: MissionReward(xp: 100),
      objective: MissionObjective(
        type: ObjectiveType.reachPopulation,
        targetValue: 100,
        description: 'Reach 100 population',
      ),
    ),
    AchievementDefinition(
      id: 'ach_population_500',
      title: 'Small Town',
      description: 'Reach a population of 500 citizens.',
      icon: '🌆',
      reward: MissionReward(xp: 300, coins: 500),
      objective: MissionObjective(
        type: ObjectiveType.reachPopulation,
        targetValue: 500,
        description: 'Reach 500 population',
      ),
    ),
    AchievementDefinition(
      id: 'ach_first_park',
      title: 'Nature Lover',
      description: 'Build your first park.',
      icon: '🌳',
      reward: MissionReward(xp: 50),
      objective: MissionObjective(
        type: ObjectiveType.buildParkCount,
        targetValue: 1,
        description: 'Build 1 park',
      ),
    ),
    AchievementDefinition(
      id: 'ach_5_parks',
      title: 'Green City',
      description: 'Build 5 parks or gardens.',
      icon: '🌿',
      reward: MissionReward(xp: 150, coins: 300),
      objective: MissionObjective(
        type: ObjectiveType.buildParkCount,
        targetValue: 5,
        description: 'Build 5 parks/gardens',
      ),
    ),
    AchievementDefinition(
      id: 'ach_first_solar',
      title: 'Solar Pioneer',
      description: 'Build your first solar plant.',
      icon: '☀️',
      reward: MissionReward(xp: 75),
      objective: MissionObjective(
        type: ObjectiveType.buildingTypeCount,
        targetValue: 1,
        description: 'Build 1 solar plant',
        buildingTypeId: 'solar_plant',
      ),
    ),
    AchievementDefinition(
      id: 'ach_coins_5000',
      title: 'Wealthy Mayor',
      description: 'Accumulate 5,000 coins.',
      icon: '💰',
      reward: MissionReward(xp: 150),
      objective: MissionObjective(
        type: ObjectiveType.reachCoins,
        targetValue: 5000,
        description: 'Have 5,000 coins',
      ),
    ),
    AchievementDefinition(
      id: 'ach_happy_city',
      title: 'Happy Place',
      description: 'Achieve 75% city happiness.',
      icon: '😊',
      reward: MissionReward(xp: 200, coins: 500),
      objective: MissionObjective(
        type: ObjectiveType.reachHappiness,
        targetValue: 75,
        description: 'Reach 75% happiness',
      ),
    ),
    AchievementDefinition(
      id: 'ach_full_services',
      title: 'Full Service City',
      description: 'Build a hospital, school, police station, and fire station.',
      icon: '🏥',
      reward: MissionReward(xp: 350, coins: 1000),
      objective: MissionObjective(
        type: ObjectiveType.buildingCategoryCount,
        targetValue: 4,
        description: 'Build 4+ public service buildings',
        buildingCategoryId: 'publicServices',
      ),
    ),
    AchievementDefinition(
      id: 'ach_employment',
      title: 'Job Creator',
      description: 'Reach 70% employment rate.',
      icon: '💼',
      reward: MissionReward(xp: 175),
      objective: MissionObjective(
        type: ObjectiveType.improveEmployment,
        targetValue: 70,
        description: 'Reach 70% employment rate',
      ),
    ),
  ];

  static AchievementDefinition? findById(String id) {
    try {
      return all.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}
