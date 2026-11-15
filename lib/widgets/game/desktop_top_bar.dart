import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/constants/app_routes.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/core/utils/number_format.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/widgets/city_logo.dart';
import 'package:city_builder_2040/widgets/game/resource_chip.dart';
import 'package:city_builder_2040/widgets/game/simulation_speed_control.dart';

/// Expanded resource dashboard for desktop: logo and city name on the left,
/// large resource cards in the middle, simulation speed and utility buttons on the right.
class DesktopTopBar extends ConsumerWidget {
  const DesktopTopBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final city = ref.watch(activeCityProvider);
    final stats = ref.watch(cityStatsProvider);
    if (city == null || stats == null) return const SizedBox.shrink();

    final textTheme = Theme.of(context).textTheme;
    final happiness = happinessStyle(stats.happiness);

    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.skyGradient),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            const CityLogo(size: 44),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    city.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.headlineMedium?.copyWith(
                      color: AppColors.textOnDark,
                      fontSize: 22,
                    ),
                  ),
                  Text(
                    'Level ${stats.level}  |  Day ${city.day}  |  ${city.mapWidth} x ${city.mapHeight} tiles',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.aqua,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              flex: 5,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                alignment: WrapAlignment.center,
                children: [
                  ResourceCard(
                    icon: Icons.monetization_on_rounded,
                    value: formatNumber(stats.coins),
                    label: 'Coins',
                    color: AppColors.sunrise,
                  ),
                  ResourceCard(
                    icon: Icons.groups_rounded,
                    value: formatNumber(stats.population),
                    label: 'Population',
                    color: AppColors.sky,
                  ),
                  ResourceCard(
                    icon: Icons.bolt_rounded,
                    value: '${stats.electricity}%',
                    label: 'Power',
                    color: AppColors.sunrise,
                    progress: stats.electricity / 100,
                  ),
                  ResourceCard(
                    icon: Icons.water_drop_rounded,
                    value: '${stats.water}%',
                    label: 'Water',
                    color: AppColors.aqua,
                    progress: stats.water / 100,
                  ),
                  ResourceCard(
                    icon: happiness.icon,
                    value: '${stats.happiness}%',
                    label: 'Happiness',
                    color: happiness.color,
                    progress: stats.happiness / 100,
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            const SimulationSpeedControl(),
            const SizedBox(width: AppSpacing.xs),
            IconButton(
              tooltip: 'Settings',
              color: AppColors.textOnDark,
              icon: const Icon(Icons.settings_rounded),
              onPressed:
                  () => Navigator.of(context).pushNamed(AppRoutes.settings),
            ),
            IconButton(
              tooltip: 'Back to menu',
              color: AppColors.textOnDark,
              icon: const Icon(Icons.logout_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
      ),
    );
  }
}
