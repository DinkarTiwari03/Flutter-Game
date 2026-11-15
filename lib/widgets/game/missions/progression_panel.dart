import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/core/utils/number_format.dart';
import 'package:city_builder_2040/models/player_progress.dart';
import 'package:city_builder_2040/providers/progression_providers.dart';
import 'package:city_builder_2040/widgets/game_card.dart';

class ProgressionPanel extends ConsumerWidget {
  const ProgressionPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerAsync = ref.watch(playerProgressProvider);
    return playerAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (player) => _ProgressionContent(player: player),
    );
  }
}

class _ProgressionContent extends StatelessWidget {
  const _ProgressionContent({required this.player});
  final PlayerProgress player;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Level card
          GameCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        gradient: AppColors.tealGradient,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${player.level}',
                          style: textTheme.headlineSmall?.copyWith(
                            color: AppColors.navy,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mayor Level ${player.level}',
                            style: textTheme.titleMedium,
                          ),
                          Text(
                            player.isMaxLevel
                                ? 'Maximum level reached!'
                                : '${formatNumber(player.experience)} / ${formatNumber(player.xpAtNextLevel)} XP',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: LinearProgressIndicator(
                    value: player.levelProgress,
                    backgroundColor: AppColors.divider,
                    valueColor: const AlwaysStoppedAnimation(AppColors.teal),
                    minHeight: 8,
                  ),
                ),
                if (!player.isMaxLevel) ...[
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '${formatNumber(player.xpForNextLevel)} XP to next level',
                      style: textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.star_rounded,
                  color: AppColors.sky,
                  label: 'Total XP',
                  value: formatNumber(player.experience),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _StatCard(
                  icon: Icons.emoji_events_rounded,
                  color: AppColors.sunrise,
                  label: 'Achievements',
                  value: '${player.completedAchievementIds.length}',
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _StatCard(
                  icon: Icons.check_circle_rounded,
                  color: AppColors.aqua,
                  label: 'Missions Done',
                  value: '${player.claimedMissionIds.length}',
                ),
              ),
            ],
          ),

          if (player.unlockedIds.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('Unlocked Content', style: textTheme.titleSmall),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: player.unlockedIds
                  .map((id) => Chip(
                        label: Text(id),
                        labelStyle: textTheme.labelSmall,
                        backgroundColor: AppColors.teal.withAlpha(30),
                        side: BorderSide.none,
                        padding: EdgeInsets.zero,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GameCard(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: textTheme.titleSmall?.copyWith(color: color)),
          Text(
            label,
            style:
                textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
