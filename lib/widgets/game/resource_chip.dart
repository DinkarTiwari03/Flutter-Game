import 'package:flutter/material.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';

/// Icon and color used to show a happiness percentage.
({IconData icon, Color color}) happinessStyle(int happiness) {
  if (happiness >= 70) {
    return (
      icon: Icons.sentiment_very_satisfied_rounded,
      color: AppColors.aqua,
    );
  }
  if (happiness >= 40) {
    return (icon: Icons.sentiment_neutral_rounded, color: AppColors.sunrise);
  }
  return (
    icon: Icons.sentiment_very_dissatisfied_rounded,
    color: AppColors.coral,
  );
}

/// Compact pill showing one resource: icon plus value. Used on dark
/// gradient bars. [label] is announced to screen readers and shown as a
/// tooltip.
class ResourceChip extends StatelessWidget {
  const ResourceChip({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = AppColors.aqua,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.onDarkTrack,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: AppSpacing.xxs + 2),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      color: AppColors.textOnDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Larger resource tile for the desktop dashboard: icon, big value and a
/// caption.
class ResourceCard extends StatelessWidget {
  const ResourceCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.color = AppColors.aqua,
    this.progress,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  /// Optional 0 to 1 bar under the value (used for happiness).
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.onDarkTrack,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(width: AppSpacing.sm),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textOnDark.withAlpha(180),
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value,
                    style: textTheme.titleLarge?.copyWith(
                      color: AppColors.textOnDark,
                    ),
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    SizedBox(
                      width: 96,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 5,
                          color: color,
                          backgroundColor: AppColors.onDarkTrack,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
