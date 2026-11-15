import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/models/tutorial_step.dart';
import 'package:city_builder_2040/providers/tutorial_provider.dart';

/// Semi-transparent overlay that guides first-time players through the UI.
///
/// Renders only when [tutorialProvider] has an active step. Place this as
/// the last child of a [Stack] so it appears above the game view.
class TutorialOverlay extends ConsumerWidget {
  const TutorialOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = ref.watch(tutorialProvider);
    if (step == null) return const SizedBox.shrink();

    final notifier = ref.read(tutorialProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return Positioned(
      top: 68,
      left: AppSpacing.md,
      right: AppSpacing.md,
      child: SafeArea(
        bottom: false,
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.navy, AppColors.deepBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.cardShadow,
                  blurRadius: 20,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.teal.withAlpha(40),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: AppColors.teal,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          step.title,
                          style: textTheme.titleMedium?.copyWith(
                            color: AppColors.textOnDark,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Skip tutorial',
                        icon: const Icon(Icons.close_rounded,
                            color: AppColors.textOnDark, size: 20),
                        onPressed: notifier.dismiss,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    step.description,
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textOnDark.withAlpha(220),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _StepIndicator(step: step),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          foregroundColor: AppColors.navy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: notifier.advance,
                        child: Text(step.isLast ? 'Finish' : 'Next'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});
  final TutorialStep step;

  @override
  Widget build(BuildContext context) {
    final total = TutorialStep.values.length - 1; // exclude 'done'
    final current = TutorialStep.values.indexOf(step) + 1;
    return Text(
      'Step $current of $total',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.textOnDark.withAlpha(160),
          ),
    );
  }
}
