import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/core/utils/number_format.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/providers/building_providers.dart';
import 'package:city_builder_2040/providers/game_providers.dart';

/// Interactive menu for browsing and selecting buildings to construct.
class BuildingSelectionMenu extends ConsumerStatefulWidget {
  const BuildingSelectionMenu({super.key, this.initialCategory});

  final BuildingCategory? initialCategory;

  @override
  ConsumerState<BuildingSelectionMenu> createState() =>
      _BuildingSelectionMenuState();
}

class _BuildingSelectionMenuState extends ConsumerState<BuildingSelectionMenu> {
  late BuildingCategory _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.initialCategory ?? BuildingCategory.residential;
  }

  @override
  Widget build(BuildContext context) {
    final buildings = BuildingRegistry.byCategory(_selectedCategory);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Category tabs
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final cat in BuildingCategory.values) ...[
                _CategoryChip(
                  category: cat,
                  selected: cat == _selectedCategory,
                  onSelected: () => setState(() => _selectedCategory = cat),
                ),
                const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Building cards grid
        for (final def in buildings) ...[
          _BuildingOptionCard(
            definition: def,
            onSelect: () {
              ref.read(placementProvider.notifier).startPlacement(def);
              // Close section panel / sheet so the map is visible for placement
              ref.read(activeSectionProvider.notifier).close();
            },
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.category,
    required this.selected,
    required this.onSelected,
  });

  final BuildingCategory category;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.xs),
        onTap: onSelected,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? category.color : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.xs),
            border: Border.all(
              color: selected ? category.color : AppColors.divider,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                category.icon,
                size: 16,
                color: selected ? Colors.white : AppColors.deepBlue,
              ),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                category.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppColors.deepBlue,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BuildingOptionCard extends StatelessWidget {
  const _BuildingOptionCard({
    required this.definition,
    required this.onSelect,
  });

  final BuildingDefinition definition;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: definition.accentColor.withAlpha(35),
                borderRadius: BorderRadius.circular(AppRadius.xs),
              ),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Icon(
                  definition.icon,
                  color: definition.accentColor,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          definition.name,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: Text(
                          '${definition.width}x${definition.height}',
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.teal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    definition.description,
                    style: textTheme.bodySmall?.copyWith(fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.monetization_on_rounded,
                        size: 14,
                        color: AppColors.sunrise,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        formatNumber(definition.cost),
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.deepBlue,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.teal,
                foregroundColor: AppColors.navy,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
              ),
              onPressed: onSelect,
              child: const Text(
                'Build',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
