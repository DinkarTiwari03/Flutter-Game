import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/game/missions/mission_definition.dart';
import 'package:city_builder_2040/providers/progression_providers.dart';
import 'package:city_builder_2040/widgets/game/missions/mission_card.dart';

class ChallengesPanel extends ConsumerWidget {
  const ChallengesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allProgress = ref.watch(cityMissionProgressProvider).value ?? [];
    final progressMap = {for (final p in allProgress) p.missionId: p};
    final challenges = ref.watch(availableChallengesProvider);

    if (challenges.isEmpty) {
      return const Center(
        child: Text(
          'No challenges available',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    // Group challenges by difficulty
    final beginner = challenges
        .where((c) => c.difficulty == MissionDifficulty.beginner)
        .toList();
    final intermediate = challenges
        .where((c) => c.difficulty == MissionDifficulty.intermediate)
        .toList();
    final advanced = challenges
        .where((c) => c.difficulty == MissionDifficulty.advanced)
        .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (beginner.isNotEmpty) ...[
            const _DifficultyHeader(
                label: 'Beginner Challenges', color: AppColors.aqua),
            const SizedBox(height: AppSpacing.xs),
            ...beginner.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: MissionCard(mission: c, progress: progressMap[c.id]),
                )),
          ],
          if (intermediate.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            const _DifficultyHeader(
                label: 'Intermediate Challenges', color: AppColors.sunrise),
            const SizedBox(height: AppSpacing.xs),
            ...intermediate.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: MissionCard(mission: c, progress: progressMap[c.id]),
                )),
          ],
          if (advanced.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            const _DifficultyHeader(
                label: 'Advanced Challenges', color: AppColors.coral),
            const SizedBox(height: AppSpacing.xs),
            ...advanced.map((c) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: MissionCard(mission: c, progress: progressMap[c.id]),
                )),
          ],
        ],
      ),
    );
  }
}

class _DifficultyHeader extends StatelessWidget {
  const _DifficultyHeader({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
