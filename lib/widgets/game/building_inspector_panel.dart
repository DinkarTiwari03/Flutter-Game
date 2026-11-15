import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/core/utils/number_format.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/providers/building_providers.dart';
import 'package:city_builder_2040/widgets/game_card.dart';

/// Inspection and management panel for a placed building.
///
/// Provides building status, upgrade controls, and demolition interface with
/// calculated refund amounts.
class BuildingInspectorPanel extends ConsumerWidget {
  const BuildingInspectorPanel({
    super.key,
    required this.building,
    this.onClose,
  });

  final Building building;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final def = BuildingRegistry.get(building.typeId);
    if (def == null) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final isMaxLevel = building.level >= def.maxLevel;
    final upgradeCost = def.upgradeCost(building.level);
    final refund = def.demolitionRefund(building.level);

    return GameCard(
      key: const ValueKey('building-inspector-panel'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: def.accentColor.withAlpha(40),
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xs),
                  child: Icon(def.icon, color: def.accentColor, size: 28),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.name,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      def.category.label,
                      style: textTheme.bodySmall?.copyWith(
                        color: def.accentColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: 'Close inspector',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClose,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Level & footprint stats
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _StatColumn(
                    label: 'LEVEL',
                    value: 'Lv. ${building.level} / ${def.maxLevel}',
                    valueColor: AppColors.deepBlue,
                  ),
                  _StatColumn(
                    label: 'GRID',
                    value: '(${building.x}, ${building.y})',
                    valueColor: AppColors.deepBlue,
                  ),
                  _StatColumn(
                    label: 'SIZE',
                    value: '${def.width}x${def.height}',
                    valueColor: AppColors.teal,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Upgrade Interface
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.divider),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMaxLevel ? 'Maximum Level Reached' : 'Upgrade Building',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (!isMaxLevel && upgradeCost != null) ...[
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
                                formatNumber(upgradeCost),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.deepBlue,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  ElevatedButton(
                    key: const ValueKey('btn-upgrade-building'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isMaxLevel ? Colors.grey.shade300 : AppColors.teal,
                      foregroundColor: AppColors.navy,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                    ),
                    onPressed: isMaxLevel
                        ? null
                        : () async {
                            await ref
                                .read(cityBuildingsProvider.notifier)
                                .upgradeBuilding(building.id);
                          },
                    child: Text(
                      isMaxLevel ? 'Max' : 'Upgrade',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),

          // Demolition Interface
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.divider),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Demolish Structure',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.coral,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Refund: +${formatNumber(refund)} coins',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    key: const ValueKey('btn-demolish-building'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.coral,
                      side: const BorderSide(color: AppColors.coral),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                    ),
                    onPressed: () async {
                      await ref
                          .read(cityBuildingsProvider.notifier)
                          .demolishBuilding(building.id);
                      ref.read(selectedBuildingIdProvider.notifier).clear();
                    },
                    child: const Text(
                      'Demolish',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
