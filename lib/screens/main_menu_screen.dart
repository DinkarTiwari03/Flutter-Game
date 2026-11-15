import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/constants/app_constants.dart';
import 'package:city_builder_2040/core/constants/app_routes.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/core/utils/responsive.dart';
import 'package:city_builder_2040/providers/active_city_provider.dart';
import 'package:city_builder_2040/widgets/about_game_dialog.dart';
import 'package:city_builder_2040/widgets/city_backdrop.dart';
import 'package:city_builder_2040/widgets/city_logo.dart';
import 'package:city_builder_2040/widgets/game_button.dart';
import 'package:city_builder_2040/widgets/responsive_center.dart';

class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    final logoSize = context.responsive(
      compact: 88.0,
      medium: 104.0,
      expanded: 112.0,
    );
    final latestCityAsync = ref.watch(latestCityProvider);
    final latestCity = latestCityAsync.value;

    return Scaffold(
      body: CityBackdrop(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ResponsiveCenter(
                    maxWidth: 420,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CityLogo(size: logoSize),
                        const SizedBox(height: AppSpacing.lg),
                        const GameTitle(),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          AppConstants.tagline,
                          textAlign: TextAlign.center,
                          style: textTheme.bodyLarge?.copyWith(
                            color: AppColors.textOnDark,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        GameButton(
                          label: 'Play',
                          icon: Icons.play_arrow_rounded,
                          onPressed: () => Navigator.of(context)
                              .pushNamed(AppRoutes.newGame),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        GameButton(
                          label: latestCity != null
                              ? 'Continue (${latestCity.name})'
                              : 'Continue',
                          icon: Icons.history_rounded,
                          onPressed: latestCity != null
                              ? () {
                                  ref
                                      .read(activeCityProvider.notifier)
                                      .open(latestCity);
                                  Navigator.of(context)
                                      .pushNamed(AppRoutes.game);
                                }
                              : null,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        GameButton(
                          label: 'Settings',
                          icon: Icons.tune_rounded,
                          variant: GameButtonVariant.secondary,
                          onPressed: () => Navigator.of(context)
                              .pushNamed(AppRoutes.settings),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        GameButton(
                          label: 'About',
                          icon: Icons.info_outline_rounded,
                          variant: GameButtonVariant.secondary,
                          onPressed: () => showAboutGameDialog(context),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'v${AppConstants.version}',
                          style: textTheme.bodyMedium?.copyWith(
                            color: AppColors.textOnDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
