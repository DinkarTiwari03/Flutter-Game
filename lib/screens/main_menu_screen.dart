import 'package:flutter/material.dart';
import 'package:city_builder_2040/core/constants/app_constants.dart';
import 'package:city_builder_2040/core/constants/app_routes.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/core/utils/responsive.dart';
import 'package:city_builder_2040/widgets/about_game_dialog.dart';
import 'package:city_builder_2040/widgets/city_backdrop.dart';
import 'package:city_builder_2040/widgets/city_logo.dart';
import 'package:city_builder_2040/widgets/game_button.dart';
import 'package:city_builder_2040/widgets/responsive_center.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final logoSize = context.responsive(
      compact: 88.0,
      medium: 104.0,
      expanded: 112.0,
    );

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
                        // Enabled once game persistence exists.
                        const GameButton(
                          label: 'Continue',
                          icon: Icons.history_rounded,
                          onPressed: null,
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
