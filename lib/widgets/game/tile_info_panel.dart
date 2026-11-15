import 'package:flutter/material.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/core/theme/map_colors.dart';
import 'package:city_builder_2040/game/map/tile_info.dart';
import 'package:city_builder_2040/game/map/tile_type.dart';
import 'package:city_builder_2040/widgets/game_card.dart';

Color _swatchColor(TileType type) {
  return switch (type) {
    TileType.grass => MapColors.grassShades.first,
    TileType.sand => MapColors.sandShades.first,
    TileType.water => MapColors.waterShades.first,
    TileType.road => MapColors.asphalt,
  };
}

IconData _tileIcon(TileType type) {
  return switch (type) {
    TileType.grass => Icons.grass_rounded,
    TileType.sand => Icons.beach_access_rounded,
    TileType.water => Icons.water_rounded,
    TileType.road => Icons.add_road_rounded,
  };
}

class _TileBadge extends StatelessWidget {
  const _TileBadge({required this.type});

  final TileType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: _swatchColor(type),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Icon(_tileIcon(type), color: Colors.white),
    );
  }
}

/// Compact card shown over the map on phones when a tile is selected.
class TileInfoCard extends StatelessWidget {
  const TileInfoCard({super.key, required this.info, required this.onClose});

  final TileInfo info;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GameCard(
      key: const ValueKey('tile-info-panel'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TileBadge(type: info.type),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(info.title, style: textTheme.titleLarge),
                Text('Tile ${info.coordinates}', style: textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                Text(info.type.description, style: textTheme.bodyMedium),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xxs,
                  children: [
                    _Tag(
                      label: info.buildStatus,
                      positive: info.type.isBuildable,
                    ),
                    if (info.isRoad)
                      _Tag(
                        label:
                            info.roadLinks.isEmpty
                                ? 'No connections'
                                : '${info.roadLinks.length} connection'
                                    '${info.roadLinks.length == 1 ? '' : 's'}',
                        positive: info.roadLinks.isNotEmpty,
                      )
                    else if (info.hasObstacle)
                      _Tag(label: info.decoration.label, positive: false),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Deselect',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.close_rounded),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.positive});

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final color = positive ? AppColors.teal : AppColors.textSecondary;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// Full inspection panel for the desktop right-hand side.
class TileInfoSidebar extends StatelessWidget {
  const TileInfoSidebar({super.key, required this.info, this.onClose});

  final TileInfo? info;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final info = this.info;

    if (info == null) {
      return GameCard(
        key: const ValueKey('tile-info-empty'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.touch_app_rounded,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text('Nothing selected', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Click a tile on the map to inspect it.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return GameCard(
      key: const ValueKey('tile-info-panel'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _TileBadge(type: info.type),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(info.title, style: textTheme.titleLarge),
                    Text(
                      'Tile ${info.coordinates}',
                      style: textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  tooltip: 'Deselect (Esc)',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClose,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(info.type.description, style: textTheme.bodyMedium),
          const Divider(height: AppSpacing.lg),
          for (final (label, value) in info.details)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 96,
                    child: Text(label, style: textTheme.bodyMedium),
                  ),
                  Expanded(
                    child: Text(
                      value,
                      style: textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
