import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/core/utils/number_format.dart';
import 'package:city_builder_2040/game/missions/mission_definition.dart';
import 'package:city_builder_2040/models/mission_progress.dart';
import 'package:city_builder_2040/providers/progression_providers.dart';
import 'package:city_builder_2040/widgets/game_card.dart';

class MissionCard extends ConsumerWidget {
  const MissionCard({
    super.key,
    required this.mission,
    required this.progress,
  });

  final MissionDefinition mission;
  final MissionProgress? progress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final status = progress?.status ?? MissionStatus.locked;
    final progressValue = progress?.progress ?? 0.0;
    final rewardClaimed = progress?.rewardClaimed ?? false;

    final categoryColor = _categoryColor(mission.category);
    final difficultyLabel = _difficultyLabel(mission.difficulty);
    final difficultyColor = _difficultyColor(mission.difficulty);

    return GameCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: categoryColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Center(
                  child: Text(
                    mission.category.emoji,
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mission.title,
                      style: textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: 2,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: difficultyColor.withAlpha(40),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Text(
                            difficultyLabel,
                            style: textTheme.labelSmall?.copyWith(
                              color: difficultyColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.xs,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: categoryColor.withAlpha(30),
                            borderRadius: BorderRadius.circular(AppRadius.xs),
                          ),
                          child: Text(
                            mission.category.label,
                            style: textTheme.labelSmall?.copyWith(
                              color: categoryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _StatusBadge(status: status, rewardClaimed: rewardClaimed),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            mission.description,
            style: textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.xs),

          // Objectives
          ...mission.objectives.map(
            (obj) => Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: _ObjectiveRow(
                description: obj.description,
                progress: progress != null ? progressValue : 0.0,
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xs),
          // Rewards row
          _RewardRow(reward: mission.reward),

          // Claim button (only when completed and not yet claimed)
          if (status == MissionStatus.completed && !rewardClaimed) ...[
            const SizedBox(height: AppSpacing.xs),
            FilledButton.icon(
              onPressed: () async {
                final events = await ref
                    .read(cityMissionProgressProvider.notifier)
                    .claimReward(mission.id);
                for (final event in events) {
                  ref
                      .read(pendingProgressionEventsProvider.notifier)
                      .add(event);
                }
              },
              icon: const Icon(Icons.card_giftcard_rounded, size: 16),
              label: const Text('Claim Reward'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
              ),
            ),
          ],
          if (status == MissionStatus.locked)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  const Icon(Icons.lock_rounded,
                      size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: AppSpacing.xxs),
                  Expanded(
                    child: Text(
                      'Complete prerequisites to unlock',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Color _categoryColor(MissionCategory cat) {
    return switch (cat) {
      MissionCategory.construction => AppColors.sunrise,
      MissionCategory.population => AppColors.teal,
      MissionCategory.economy => AppColors.sky,
      MissionCategory.sustainability => AppColors.aqua,
    };
  }

  String _difficultyLabel(MissionDifficulty diff) => switch (diff) {
        MissionDifficulty.beginner => 'Beginner',
        MissionDifficulty.intermediate => 'Intermediate',
        MissionDifficulty.advanced => 'Advanced',
      };

  Color _difficultyColor(MissionDifficulty diff) => switch (diff) {
        MissionDifficulty.beginner => AppColors.aqua,
        MissionDifficulty.intermediate => AppColors.sunrise,
        MissionDifficulty.advanced => AppColors.coral,
      };
}

class _ObjectiveRow extends StatelessWidget {
  const _ObjectiveRow({required this.description, required this.progress});
  final String description;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final pct = (progress * 100).round().clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                description,
                style: textTheme.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$pct%',
              style: textTheme.labelSmall?.copyWith(
                color:
                    progress >= 1.0 ? AppColors.aqua : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: AppColors.divider,
            valueColor: AlwaysStoppedAnimation(
              progress >= 1.0 ? AppColors.aqua : AppColors.teal,
            ),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.reward});
  final MissionReward reward;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.xxs,
      runSpacing: 2,
      children: [
        const Icon(Icons.card_giftcard_rounded,
            size: 14, color: AppColors.textSecondary),
        Text('Reward: ',
            style:
                textTheme.labelSmall?.copyWith(color: AppColors.textSecondary)),
        if (reward.coins > 0) ...[
          const Icon(Icons.monetization_on_rounded,
              size: 12, color: AppColors.sunrise),
          Text(formatNumber(reward.coins),
              style:
                  textTheme.labelSmall?.copyWith(color: AppColors.sunrise)),
          const SizedBox(width: AppSpacing.xxs),
        ],
        if (reward.xp > 0) ...[
          const Icon(Icons.star_rounded, size: 12, color: AppColors.sky),
          Text('+${reward.xp} XP',
              style: textTheme.labelSmall?.copyWith(color: AppColors.sky)),
          const SizedBox(width: AppSpacing.xxs),
        ],
        if (reward.unlockedBuildingIds.isNotEmpty) ...[
          const Icon(Icons.lock_open_rounded, size: 12, color: AppColors.teal),
          Text('Unlock',
              style: textTheme.labelSmall?.copyWith(color: AppColors.teal)),
        ],
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status, required this.rewardClaimed});
  final MissionStatus status;
  final bool rewardClaimed;

  @override
  Widget build(BuildContext context) {
    if (status == MissionStatus.completed && rewardClaimed) {
      return const Icon(Icons.check_circle_rounded,
          color: AppColors.aqua, size: 20);
    }
    if (status == MissionStatus.completed) {
      return const Icon(Icons.emoji_events_rounded,
          color: AppColors.sunrise, size: 20);
    }
    if (status == MissionStatus.locked) {
      return const Icon(Icons.lock_rounded,
          color: AppColors.textSecondary, size: 18);
    }
    return const SizedBox.shrink();
  }
}
