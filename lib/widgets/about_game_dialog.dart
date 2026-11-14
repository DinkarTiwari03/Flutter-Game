import 'package:flutter/material.dart';
import 'package:city_builder_2040/core/constants/app_constants.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/widgets/city_logo.dart';
import 'package:city_builder_2040/widgets/game_button.dart';

Future<void> showAboutGameDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _AboutGameDialog(),
  );
}

class _AboutGameDialog extends StatelessWidget {
  const _AboutGameDialog();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Dialog(
      backgroundColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CityLogo(size: 64),
              const SizedBox(height: AppSpacing.md),
              Text(AppConstants.appName, style: textTheme.titleLarge),
              Text(
                'Version ${AppConstants.version}',
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Plan, build and power the smart city of the future.',
                style: textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              GameButton(
                label: 'Close',
                variant: GameButtonVariant.secondary,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
