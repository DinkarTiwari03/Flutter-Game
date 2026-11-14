import 'package:flutter/material.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/widgets/game_button.dart';
import 'package:city_builder_2040/widgets/game_card.dart';
import 'package:city_builder_2040/widgets/game_scaffold.dart';

class NewGameScreen extends StatelessWidget {
  const NewGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GameScaffold(
      title: 'New Game',
      subtitle: 'Found your city',
      child: Column(
        children: [
          GameCard(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    gradient: AppColors.tealGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.apartment_rounded,
                    size: 36,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text('Your city starts here', style: textTheme.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'City name, map size and difficulty options will appear '
                  'here in a later phase.',
                  style: textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GameButton(
            label: 'Back to menu',
            icon: Icons.arrow_back_rounded,
            variant: GameButtonVariant.secondary,
            onPressed: () => Navigator.of(context).maybePop(),
          ),
        ],
      ),
    );
  }
}
