import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/game/buildings/building_definition.dart';
import 'package:city_builder_2040/models/traffic/traffic_models.dart';
import 'package:city_builder_2040/providers/building_providers.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/providers/urban_providers.dart';

/// Comprehensive Traffic Management Dashboard providing real-time analytics,
/// congestion monitoring, public transit metrics, and road management tools.
class TrafficDashboardView extends ConsumerWidget {
  const TrafficDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(trafficMetricsProvider);
    final showHeatmap = ref.watch(trafficHeatmapVisibleProvider);
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top Summary Grid ──
          _TrafficSummaryGrid(metrics: metrics, tt: tt),
          const SizedBox(height: AppSpacing.md),

          // ── Heatmap Overlay Switcher & Legend ──
          _HeatmapToggleCard(
            showHeatmap: showHeatmap,
            tt: tt,
            onToggle: () =>
                ref.read(trafficHeatmapVisibleProvider.notifier).toggle(),
          ),
          const SizedBox(height: AppSpacing.md),

          // ── Public Transportation & Economic Impact ──
          _TransitAndEconomyRow(metrics: metrics, tt: tt),
          const SizedBox(height: AppSpacing.md),

          // ── Actionable Alerts ──
          if (metrics.alerts.isNotEmpty) ...[
            _SectionTitle(
              title: 'Actionable Alerts (${metrics.alerts.length})',
              icon: Icons.notification_important_rounded,
              color: AppColors.coral,
              tt: tt,
            ),
            const SizedBox(height: AppSpacing.xs),
            ...metrics.alerts.map((alert) => _AlertCard(alert: alert, tt: tt)),
            const SizedBox(height: AppSpacing.md),
          ],

          // ── Congestion Hotspots ──
          _SectionTitle(
            title: 'Major Traffic Hotspots',
            icon: Icons.local_fire_department_rounded,
            color: metrics.hotspots.isNotEmpty ? AppColors.coral : AppColors.teal,
            tt: tt,
          ),
          const SizedBox(height: AppSpacing.xs),
          _HotspotsList(metrics: metrics, tt: tt),
          const SizedBox(height: AppSpacing.md),

          // ── Road Works & Construction Quick Actions ──
          _SectionTitle(
            title: 'Transit Infrastructure Works',
            icon: Icons.alt_route_rounded,
            color: AppColors.aqua,
            tt: tt,
          ),
          const SizedBox(height: AppSpacing.xs),
          const _TransitBuildingPalette(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.icon,
    required this.color,
    required this.tt,
  });

  final String title;
  final IconData icon;
  final Color color;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          title,
          style: tt.labelLarge?.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TrafficSummaryGrid extends StatelessWidget {
  const _TrafficSummaryGrid({required this.metrics, required this.tt});

  final TrafficMetrics metrics;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 340;
        final halfW = (constraints.maxWidth - AppSpacing.sm) / 2;
        return Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            _MetricCard(
              width: isNarrow ? constraints.maxWidth : halfW,
              title: 'City Congestion',
              value: '${metrics.overallCongestionPercent}%',
              subtitle: metrics.condition.label,
              badgeColor: metrics.condition.color,
              icon: Icons.traffic_rounded,
              tt: tt,
            ),
            _MetricCard(
              width: isNarrow ? constraints.maxWidth : halfW,
              title: 'Active Vehicles',
              value: '${metrics.totalActiveVehicles}',
              subtitle: 'Moving on road network',
              badgeColor: AppColors.aqua,
              icon: Icons.directions_car_rounded,
              tt: tt,
            ),
            _MetricCard(
              width: isNarrow ? constraints.maxWidth : halfW,
              title: 'Average Speed',
              value: '${metrics.averageSpeed.round()} px/s',
              subtitle: 'City-wide road velocity',
              badgeColor: metrics.averageSpeed < 35 ? AppColors.coral : AppColors.teal,
              icon: Icons.speed_rounded,
              tt: tt,
            ),
            _MetricCard(
              width: isNarrow ? constraints.maxWidth : halfW,
              title: 'Traffic Losses',
              value: metrics.economicLossPerHour > 0
                  ? '-¢${metrics.economicLossPerHour}/hr'
                  : '¢0/hr',
              subtitle: 'Delivery & logistics delays',
              badgeColor: metrics.economicLossPerHour > 0 ? AppColors.coral : AppColors.teal,
              icon: Icons.trending_down_rounded,
              tt: tt,
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.width,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.badgeColor,
    required this.icon,
    required this.tt,
  });

  final double width;
  final String title;
  final String value;
  final String subtitle;
  final Color badgeColor;
  final IconData icon;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: tt.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              Icon(icon, size: 16, color: badgeColor),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: tt.titleMedium?.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: tt.bodySmall?.copyWith(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _HeatmapToggleCard extends StatelessWidget {
  const _HeatmapToggleCard({
    required this.showHeatmap,
    required this.onToggle,
    required this.tt,
  });

  final bool showHeatmap;
  final VoidCallback onToggle;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: showHeatmap ? AppColors.teal.withAlpha(160) : AppColors.divider,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                Icons.layers_rounded,
                size: 20,
                color: showHeatmap ? AppColors.teal : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'Traffic Heatmap Overlay',
                  style: tt.labelLarge?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Switch.adaptive(
                value: showHeatmap,
                onChanged: (_) => onToggle(),
                activeColor: AppColors.teal,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Heatmap Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LegendItem(color: const Color(0xFF22C55E), label: 'Free Flow', tt: tt),
              _LegendItem(color: const Color(0xFFEAB308), label: 'Moderate', tt: tt),
              _LegendItem(color: const Color(0xFFF97316), label: 'Heavy', tt: tt),
              _LegendItem(color: const Color(0xFFEF4444), label: 'Gridlock', tt: tt),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label, required this.tt});

  final Color color;
  final String label;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: tt.bodySmall?.copyWith(color: AppColors.textSecondary, fontSize: 11),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TransitAndEconomyRow extends StatelessWidget {
  const _TransitAndEconomyRow({required this.metrics, required this.tt});

  final TrafficMetrics metrics;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_bus_rounded, size: 18, color: AppColors.sunrise),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Public Transit Impact',
                style: tt.labelLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bus Ridership',
                      style: tt.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                    Text(
                      '${metrics.publicTransitRidership} riders',
                      style: tt.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Car Demand Relief',
                      style: tt.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                    Text(
                      '-${metrics.trafficDemandReductionPercent}% traffic',
                      style: tt.bodyMedium?.copyWith(
                        color: AppColors.teal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.tt});

  final TrafficAlert alert;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: alert.severity.color.withAlpha(25),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: alert.severity.color.withAlpha(120)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, size: 16, color: alert.severity.color),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  alert.title,
                  style: tt.bodyMedium?.copyWith(
                    color: alert.severity.color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            alert.message,
            style: tt.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          if (alert.recommendedAction != null) ...[
            const SizedBox(height: 4),
            Text(
              '💡 ${alert.recommendedAction}',
              style: tt.bodySmall?.copyWith(
                color: AppColors.aqua,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _HotspotsList extends ConsumerWidget {
  const _HotspotsList({required this.metrics, required this.tt});

  final TrafficMetrics metrics;
  final TextTheme tt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (metrics.hotspots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.divider),
        ),
        child: Center(
          child: Text(
            'No major traffic bottlenecks. Roads are free-flowing!',
            style: tt.bodySmall?.copyWith(color: AppColors.teal),
          ),
        ),
      );
    }

    return Column(
      children: metrics.hotspots.map((pt) {
        final stats = metrics.segmentStats[pt];
        final tier = stats?.tier ?? RoadTier.small;
        final condition = stats?.condition ?? TrafficCondition.moderate;

        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 32,
                decoration: BoxDecoration(
                  color: condition.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Road at (${pt.col}, ${pt.row}) • ${tier.name}',
                      style: tt.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${stats?.vehicleCount ?? 0} / ${tier.capacity} vehicles'
                      ' (${((stats?.loadRatio ?? 0) * 100).round()}% capacity)',
                      style: tt.bodySmall?.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (tier.level < 4)
                ElevatedButton(
                  onPressed: () {
                    ref.read(selectedTileProvider.notifier).select(pt);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: AppColors.navy,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  child: const Text('Inspect / Upgrade'),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _TransitBuildingPalette extends ConsumerWidget {
  const _TransitBuildingPalette();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tt = Theme.of(context).textTheme;
    final buildings = [
      BuildingRegistry.road,
      BuildingRegistry.busStop,
      BuildingRegistry.busStation,
    ];

    return Row(
      children: buildings.map((def) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            child: InkWell(
              onTap: () {
                ref.read(placementProvider.notifier).startPlacement(def);
                ref.read(activeSectionProvider.notifier).close();
              },
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSpacing.sm,
                  horizontal: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    Icon(def.icon, size: 24, color: AppColors.teal),
                    const SizedBox(height: 4),
                    Text(
                      def.name,
                      style: tt.bodySmall?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      '¢${def.cost}',
                      style: tt.bodySmall?.copyWith(
                        color: AppColors.sunrise,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
