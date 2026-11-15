import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/core/utils/number_format.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/game/map/tile_type.dart';
import 'package:city_builder_2040/models/game_section.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/widgets/game/building_selection_menu.dart';
import 'package:city_builder_2040/widgets/game/game_navigation.dart';
import 'package:city_builder_2040/widgets/game/missions/missions_main_panel.dart';
import 'package:city_builder_2040/widgets/game_card.dart';

/// Title row shared by the phone sheet and the desktop side panel.
class SectionPanelHeader extends StatelessWidget {
  const SectionPanelHeader({super.key, required this.section, this.onClose});

  final GameSection section;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: AppColors.tealGradient,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(gameSectionIcon(section), color: AppColors.navy),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(section.label, style: textTheme.titleLarge),
              Text(
                section.summary,
                style: textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        if (onClose != null)
          IconButton(
            tooltip: 'Close',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose,
          ),
      ],
    );
  }
}

/// Phone: a card sliding over the lower part of the map.
class SectionSheet extends StatelessWidget {
  const SectionSheet({
    super.key,
    required this.section,
    required this.onClose,
    required this.maxHeight,
  });

  final GameSection section;
  final VoidCallback onClose;
  final double maxHeight;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: GameCard(
        key: ValueKey('section-sheet-${section.name}'),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionPanelHeader(section: section, onClose: onClose),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: SingleChildScrollView(
                child: SectionPanelContent(section: section),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Desktop: a full-height panel docked beside the map.
class SectionSidePanel extends StatelessWidget {
  const SectionSidePanel({super.key, required this.section});

  final GameSection section;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: ValueKey('section-panel-${section.name}'),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(right: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionPanelHeader(section: section),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: SingleChildScrollView(
                child: SectionPanelContent(section: section),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Body of a section. Construction, economy and missions are placeholders in
/// this phase; Statistics shows real data about the generated map.
class SectionPanelContent extends ConsumerWidget {
  const SectionPanelContent({super.key, required this.section});

  final GameSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (section) {
      GameSection.build => const BuildingSelectionMenu(),
      GameSection.roads => const BuildingSelectionMenu(
        initialCategory: BuildingCategory.infrastructure,
      ),
      GameSection.economy => const _InfoRows(
        note: 'The economy is not simulated yet.',
        rows: [
          ('Tax rate', 'Not set'),
          ('Income', 'Not simulated'),
          ('Upkeep', 'Not simulated'),
        ],
      ),
      GameSection.missions => const MissionsMainPanel(),
      GameSection.statistics => const _StatisticsRows(),
    };
  }
}

class _InfoRows extends StatelessWidget {
  const _InfoRows({required this.note, required this.rows});

  final String note;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(note, style: textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        for (final (label, value) in rows) _Row(label: label, value: value),
      ],
    );
  }
}

class _StatisticsRows extends ConsumerWidget {
  const _StatisticsRows();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final map = ref.watch(gameMapProvider);
    final stats = ref.watch(cityStatsProvider);
    if (map == null || stats == null) return const SizedBox.shrink();

    final water = map.countOf(TileType.water);
    final roads = map.countOf(TileType.road);
    final buildable = map.countOf(TileType.grass) + map.countOf(TileType.sand);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Row(label: 'Map size', value: '${map.cols} x ${map.rows} tiles'),
        _Row(label: 'Total tiles', value: formatNumber(map.tileCount)),
        _Row(label: 'Buildable land', value: formatNumber(buildable)),
        _Row(label: 'Water', value: formatNumber(water)),
        _Row(label: 'Road tiles', value: formatNumber(roads)),
        const Divider(height: AppSpacing.lg),
        _Row(label: 'Population', value: formatNumber(stats.population)),
        _Row(label: 'Coins', value: formatNumber(stats.coins)),
        _Row(label: 'Happiness', value: '${stats.happiness}%'),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs + 1),
      child: Row(
        children: [
          Expanded(child: Text(label, style: textTheme.bodyMedium)),
          Text(
            value,
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
