import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/core/utils/number_format.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/models/building.dart';
import 'package:city_builder_2040/providers/building_providers.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/widgets/game_card.dart';

/// Inspection and management panel for a placed building.
///
/// Provides building status, resource impacts, upgrade controls, and demolition
/// interface with calculated refund amounts and financial validation.
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

    final currentCoins = ref.watch(cityStatsProvider)?.coins ?? 0;
    final canAffordUpgrade = !isMaxLevel && upgradeCost != null && currentCoins >= upgradeCost;

    // Building resource behavior stats
    final housing = def.effectiveHousingCapacity(building.level);
    final powerProd = def.effectiveElectricityProduction(building.level);
    final powerCons = def.effectiveElectricityConsumption(building.level);
    final waterProd = def.effectiveWaterProduction(building.level);
    final waterCons = def.effectiveWaterConsumption(building.level);
    final upkeep = def.effectiveMaintenance(building.level);
    final commercialIncome = def.effectiveCommercialIncome(building.level);
    final industrialIncome = def.effectiveIndustrialIncome(building.level);
    final pollutionOut = def.effectivePollutionOutput(building.level);
    final pollutionRed = def.effectivePollutionReduction(building.level);
    final happinessBonus = def.effectiveHappinessBonus(building.level);

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
          const SizedBox(height: AppSpacing.xs),

          // Resource behavior summary
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.divider),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: 4,
                children: [
                  if (def.isRoad)
                    _ResourceBadge(
                      icon: Icons.traffic_rounded,
                      label: 'Capacity: ${def.effectiveRoadCapacity(building.level)} veh',
                      color: AppColors.teal,
                    ),
                  if (def.isPublicTransit)
                    _ResourceBadge(
                      icon: Icons.directions_bus_rounded,
                      label: 'Transit: Cuts Congestion',
                      color: AppColors.sunrise,
                    ),
                  if (housing > 0)
                    _ResourceBadge(
                      icon: Icons.people_rounded,
                      label: 'Housing: +$housing',
                      color: AppColors.sky,
                    ),
                  if (commercialIncome > 0)
                    _ResourceBadge(
                      icon: Icons.storefront_rounded,
                      label: 'Income: +¢$commercialIncome/t',
                      color: AppColors.teal,
                    ),
                  if (industrialIncome > 0)
                    _ResourceBadge(
                      icon: Icons.precision_manufacturing_rounded,
                      label: 'Industry: +¢$industrialIncome/t',
                      color: AppColors.teal,
                    ),
                  if (upkeep > 0)
                    _ResourceBadge(
                      icon: Icons.build_rounded,
                      label: 'Upkeep: -¢$upkeep/t',
                      color: AppColors.coral,
                    ),
                  if (powerProd > 0)
                    _ResourceBadge(
                      icon: Icons.bolt_rounded,
                      label: 'Power: +${powerProd}kW',
                      color: AppColors.sunrise,
                    ),
                  if (powerCons > 0)
                    _ResourceBadge(
                      icon: Icons.bolt_rounded,
                      label: 'Power: -${powerCons}kW',
                      color: Colors.orange.shade700,
                    ),
                  if (waterProd > 0)
                    _ResourceBadge(
                      icon: Icons.water_drop_rounded,
                      label: 'Water: +${waterProd}kL',
                      color: AppColors.aqua,
                    ),
                  if (waterCons > 0)
                    _ResourceBadge(
                      icon: Icons.water_drop_rounded,
                      label: 'Water: -${waterCons}kL',
                      color: Colors.lightBlue.shade700,
                    ),
                  if (pollutionOut > 0)
                    _ResourceBadge(
                      icon: Icons.grain_rounded,
                      label: 'Pollution: +$pollutionOut',
                      color: AppColors.coral,
                    ),
                  if (pollutionRed > 0)
                    _ResourceBadge(
                      icon: Icons.eco_rounded,
                      label: 'Eco Clean: -$pollutionRed',
                      color: AppColors.aqua,
                    ),
                  if (happinessBonus > 0)
                    _ResourceBadge(
                      icon: Icons.sentiment_satisfied_rounded,
                      label: 'Happiness: +$happinessBonus',
                      color: AppColors.teal,
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
              border: Border.all(
                color: !isMaxLevel && !canAffordUpgrade
                    ? AppColors.coral.withAlpha(120)
                    : AppColors.divider,
              ),
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
                              Icon(
                                Icons.monetization_on_rounded,
                                size: 14,
                                color: canAffordUpgrade ? AppColors.sunrise : AppColors.coral,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                formatNumber(upgradeCost),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: canAffordUpgrade ? AppColors.deepBlue : AppColors.coral,
                                ),
                              ),
                              if (!canAffordUpgrade) ...[
                                const SizedBox(width: 6),
                                const Text(
                                  '(Insufficient Coins)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.coral,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  ElevatedButton(
                    key: const ValueKey('btn-upgrade-building'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isMaxLevel || !canAffordUpgrade
                          ? Colors.grey.shade300
                          : AppColors.teal,
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
                    onPressed: isMaxLevel || !canAffordUpgrade
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

class _ResourceBadge extends StatelessWidget {
  const _ResourceBadge({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade800,
          ),
        ),
      ],
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
