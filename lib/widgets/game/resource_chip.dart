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

/// Icon and color used to show an environmental pollution percentage.
({IconData icon, Color color}) pollutionStyle(int pollution) {
  if (pollution >= 50) {
    return (icon: Icons.grain_rounded, color: AppColors.coral);
  }
  if (pollution >= 25) {
    return (icon: Icons.filter_drama_rounded, color: AppColors.sunrise);
  }
  return (icon: Icons.eco_rounded, color: AppColors.aqua);
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
    this.isWarning = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final effectiveColor = isWarning ? AppColors.coral : color;

    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Tooltip(
        message: isWarning ? '$label: Warning (Insufficient / Low)' : label,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isWarning
                ? AppColors.coral.withAlpha(40)
                : AppColors.onDarkTrack,
            border: isWarning
                ? Border.all(color: AppColors.coral.withAlpha(160), width: 1.2)
                : null,
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
                Icon(icon, size: 18, color: effectiveColor),
                const SizedBox(width: AppSpacing.xxs + 2),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      color: isWarning ? AppColors.coral : AppColors.textOnDark,
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
    this.isWarning = false,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color color;

  /// Optional 0 to 1 bar under the value (used for happiness / pollution / utilities).
  final double? progress;
  final bool isWarning;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final effectiveColor = isWarning ? AppColors.coral : color;

    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isWarning
              ? AppColors.coral.withAlpha(40)
              : AppColors.onDarkTrack,
          border: isWarning
              ? Border.all(color: AppColors.coral.withAlpha(160), width: 1.2)
              : null,
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
              Icon(icon, size: 28, color: effectiveColor),
              const SizedBox(width: AppSpacing.sm),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: textTheme.bodyMedium?.copyWith(
                      color: isWarning
                          ? AppColors.coral
                          : AppColors.textOnDark.withAlpha(180),
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value,
                    style: textTheme.titleLarge?.copyWith(
                      color: isWarning ? AppColors.coral : AppColors.textOnDark,
                    ),
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    SizedBox(
                      width: 96,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress!.clamp(0.0, 1.0),
                          minHeight: 5,
                          color: effectiveColor,
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
