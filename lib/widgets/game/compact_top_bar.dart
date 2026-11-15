import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/constants/app_routes.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/core/utils/number_format.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/widgets/game/resource_chip.dart';
import 'package:city_builder_2040/widgets/game/simulation_speed_control.dart';

/// Compact resource bar for phones: city name, level, coins, population,
/// electricity, water, happiness, simulation speed and settings.
///
/// In portrait ([singleRow] false) the name and buttons sit above the chips;
/// in landscape everything shares one row to save vertical space.
class CompactTopBar extends ConsumerWidget {
  const CompactTopBar({super.key, this.singleRow = false});

  final bool singleRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(activeCityProvider);
    final stats = ref.watch(cityStatsProvider);
    if (city == null || stats == null) return const SizedBox.shrink();

    final happiness = happinessStyle(stats.happiness);
    final pollution = pollutionStyle(stats.pollution);
    final chips = [
      ResourceChip(
        icon: Icons.monetization_on_rounded,
        value: formatCompact(stats.coins),
        label: 'Coins',
        color: AppColors.sunrise,
        isWarning: stats.isLowCoins,
      ),
      ResourceChip(
        icon: Icons.groups_rounded,
        value: formatCompact(stats.population),
        label: 'Population',
        color: AppColors.sky,
      ),
      ResourceChip(
        icon: Icons.bolt_rounded,
        value: '${stats.electricity}%',
        label: 'Electricity',
        color: stats.isElectricityDeficit ? AppColors.coral : AppColors.sunrise,
        isWarning: stats.isElectricityDeficit,
      ),
      ResourceChip(
        icon: Icons.water_drop_rounded,
        value: '${stats.water}%',
        label: 'Water',
        color: stats.isWaterDeficit ? AppColors.coral : AppColors.aqua,
        isWarning: stats.isWaterDeficit,
      ),
      ResourceChip(
        icon: happiness.icon,
        value: '${stats.happiness}%',
        label: 'Happiness',
        color: happiness.color,
        isWarning: stats.isUnhappy,
      ),
      ResourceChip(
        icon: pollution.icon,
        value: '${stats.pollution}%',
        label: 'Pollution',
        color: pollution.color,
        isWarning: stats.isPolluted,
      ),
    ];

    final titleWithLevel = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            city.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.textOnDark),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.onDarkTrack,
            borderRadius: BorderRadius.circular(AppRadius.xs),
          ),
          child: Text(
            'Lv. ${stats.level}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.aqua,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );

    final menuButton = _BarIconButton(
      icon: Icons.arrow_back_rounded,
      tooltip: 'Back to menu',
      onPressed: () => Navigator.of(context).maybePop(),
    );
    final settingsButton = _BarIconButton(
      icon: Icons.settings_rounded,
      tooltip: 'Settings',
      onPressed: () => Navigator.of(context).pushNamed(AppRoutes.settings),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppColors.skyGradient,
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.lg),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xs,
            AppSpacing.xxs,
            AppSpacing.xs,
            AppSpacing.sm,
          ),
          child:
              singleRow
                  ? Row(
                    children: [
                      menuButton,
                      Flexible(flex: 2, child: titleWithLevel),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              for (var i = 0; i < chips.length; i++) ...[
                                if (i > 0)
                                  const SizedBox(width: AppSpacing.xs),
                                chips[i],
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      const SimulationSpeedControl(compact: true),
                      settingsButton,
                    ],
                  )
                  : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          menuButton,
                          Expanded(child: titleWithLevel),
                          const SimulationSpeedControl(compact: true),
                          settingsButton,
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                        ),
                        child: Row(
                          children: [
                            for (var i = 0; i < chips.length; i++) ...[
                              if (i > 0) const SizedBox(width: AppSpacing.xs),
                              chips[i],
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }
}

class _BarIconButton extends StatelessWidget {
  const _BarIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      color: AppColors.textOnDark,
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: Icon(icon),
      onPressed: onPressed,
    );
  }
}
