import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/core/utils/number_format.dart';
import 'package:city_builder_2040/providers/building_providers.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/widgets/game_card.dart';

/// Floating HUD displayed during building placement.
///
/// Shows current preview status, cost, footprint, and confirm/cancel actions.
class PlacementHud extends ConsumerWidget {
  const PlacementHud({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placement = ref.watch(placementProvider);
    final def = placement.activeDefinition;
    if (def == null) return const SizedBox.shrink();

    final validation = placement.validation;
    final isPositionValid = validation?.isValid ?? false;
    final currentCoins = ref.watch(cityStatsProvider)?.coins ?? 0;
    final hasFunds = currentCoins >= def.cost;
    final isValid = isPositionValid && hasFunds;

    final String statusMessage;
    if (!hasFunds) {
      statusMessage = 'Insufficient Coins (¢${def.cost})';
    } else {
      statusMessage = validation?.message ?? 'Positioning...';
    }

    return GameCard(
      key: const ValueKey('placement-hud'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: def.accentColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Icon(def.icon, color: def.accentColor, size: 24),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            def.name,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          '${def.width}x${def.height}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.teal,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.monetization_on_rounded,
                          size: 14,
                          color: AppColors.sunrise,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          formatNumber(def.cost),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.deepBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isValid
                      ? AppColors.teal.withAlpha(40)
                      : AppColors.coral.withAlpha(40),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  border: Border.all(
                    color: isValid ? AppColors.teal : AppColors.coral,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isValid ? Icons.check_circle_rounded : Icons.error_rounded,
                      size: 14,
                      color: isValid ? AppColors.navy : AppColors.coral,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isValid ? 'Valid' : statusMessage,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isValid ? AppColors.navy : AppColors.coral,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('btn-cancel-placement'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.deepBlue,
                    side: const BorderSide(color: AppColors.divider),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Cancel'),
                  onPressed: () {
                    ref.read(placementProvider.notifier).cancelPlacement();
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  key: const ValueKey('btn-confirm-placement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isValid ? AppColors.teal : Colors.grey.shade400,
                    foregroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text(
                    'Construct',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  onPressed: isValid
                      ? () async {
                          await ref
                              .read(placementProvider.notifier)
                              .confirmPlacement();
                        }
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
