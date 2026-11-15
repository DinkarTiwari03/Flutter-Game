import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/game/missions/achievement_definition.dart';
import 'package:city_builder_2040/providers/progression_providers.dart';
import 'package:city_builder_2040/widgets/game_card.dart';

class AchievementsPanel extends ConsumerWidget {
  const AchievementsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(playerProgressProvider);
    return playerAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (player) {
        final achieved = player.completedAchievementIds.toSet();
        final achievements = AchievementRegistry.all;
        return GridView.builder(
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 180,
            mainAxisSpacing: AppSpacing.xs,
            crossAxisSpacing: AppSpacing.xs,
            childAspectRatio: 0.85,
          ),
          itemCount: achievements.length,
          itemBuilder: (context, i) {
            final ach = achievements[i];
            final unlocked = achieved.contains(ach.id);
            return _AchievementCard(achievement: ach, unlocked: unlocked);
          },
        );
      },
    );
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({required this.achievement, required this.unlocked});
  final AchievementDefinition achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Opacity(
      opacity: unlocked ? 1.0 : 0.45,
      child: GameCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(achievement.icon, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: AppSpacing.xs),
            Text(
              achievement.title,
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color:
                    unlocked ? AppColors.textPrimary : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              achievement.description,
              style: textTheme.labelSmall
                  ?.copyWith(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.xs),
            if (unlocked)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_rounded,
                      size: 12, color: AppColors.sky),
                  const SizedBox(width: 2),
                  Text(
                    '+${achievement.reward.xp} XP',
                    style: textTheme.labelSmall?.copyWith(color: AppColors.sky),
                  ),
                ],
              )
            else
              const Icon(Icons.lock_rounded,
                  size: 14, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
