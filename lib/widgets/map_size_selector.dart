import 'package:flutter/material.dart';
import 'package:city_builder_2040/core/constants/app_constants.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/game/map/map_config.dart';

/// Row of selectable cards, one per [MapSizePreset].
class MapSizeSelector extends StatelessWidget {
  const MapSizeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final MapSizePreset selected;
  final ValueChanged<MapSizePreset> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: [
        for (final preset in MapSizePreset.values)
          _SizeOption(
            preset: preset,
            selected: preset == selected,
            onTap: () => onChanged(preset),
          ),
      ],
    );
  }
}

class _SizeOption extends StatelessWidget {
  const _SizeOption({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final MapSizePreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppRadius.md);
    return Semantics(
      button: true,
      selected: selected,
      label: '${preset.label} map, ${preset.dimensions} tiles',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: AppConstants.fastAnimation,
        decoration: BoxDecoration(
          color: selected ? AppColors.deepBlue : AppColors.surface,
          borderRadius: radius,
          border: Border.all(
            color: selected ? AppColors.teal : AppColors.divider,
            width: selected ? 2 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: ValueKey('map-size-${preset.name}'),
            borderRadius: radius,
            onTap: onTap,
            child: SizedBox(
              width: 120,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      preset.label,
                      style: textTheme.titleMedium?.copyWith(
                        color:
                            selected
                                ? AppColors.textOnDark
                                : AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      preset.dimensions,
                      style: textTheme.bodyMedium?.copyWith(
                        color:
                            selected ? AppColors.aqua : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
