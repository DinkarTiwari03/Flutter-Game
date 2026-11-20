import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/game/map/grid_point.dart';
import 'package:city_builder_2040/models/disaster/disaster_models.dart';
import 'package:city_builder_2040/providers/building_providers.dart';
import 'package:city_builder_2040/providers/disaster_providers.dart';
import 'package:city_builder_2040/providers/urban_providers.dart';

/// Comprehensive Natural Disaster Management Panel providing real-time risk assessment,
/// active emergency status, post-disaster reports, and manual scenario trigger tools.
class DisasterPanelView extends ConsumerWidget {
  const DisasterPanelView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeDisaster = ref.watch(activeDisasterProvider);
    final risks = ref.watch(disasterRisksProvider);
    final history = ref.watch(disasterHistoryProvider);
    final notifications = ref.watch(disasterNotificationsProvider);
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Active Disaster Emergency Card ──
          if (activeDisaster != null) ...[
            _ActiveDisasterCard(disaster: activeDisaster, tt: tt),
            const SizedBox(height: AppSpacing.md),
          ],

          // ── Notifications Banner ──
          if (notifications.isNotEmpty) ...[
            _SectionHeader(
              title: 'Emergency Alerts (${notifications.length})',
              icon: Icons.notification_important_rounded,
              color: AppColors.coral,
              tt: tt,
            ),
            const SizedBox(height: AppSpacing.xs),
            ...notifications.take(3).map(
                  (n) => _NotificationTile(
                    notification: n,
                    tt: tt,
                    onDismiss: () => ref
                        .read(disasterEngineProvider)
                        .dismissNotification(n.id),
                  ),
                ),
            const SizedBox(height: AppSpacing.md),
          ],

          // ── Risk Assessment Section ──
          _SectionHeader(
            title: 'Disaster Risk Assessment',
            icon: Icons.shield_rounded,
            color: AppColors.teal,
            tt: tt,
          ),
          const SizedBox(height: AppSpacing.xs),
          _RiskAssessmentCard(risks: risks, tt: tt),
          const SizedBox(height: AppSpacing.md),

          // ── Disaster History & Post-Event Reports ──
          _SectionHeader(
            title: 'Incident Log & Reports',
            icon: Icons.history_rounded,
            color: AppColors.deepBlue,
            tt: tt,
          ),
          const SizedBox(height: AppSpacing.xs),
          _DisasterHistoryView(history: history, tt: tt),
          const SizedBox(height: AppSpacing.md),

          // ── Testing / Sandbox Simulation Triggers ──
          _SectionHeader(
            title: 'Scenario & Stress Testing',
            icon: Icons.science_rounded,
            color: AppColors.sunrise,
            tt: tt,
          ),
          const SizedBox(height: AppSpacing.xs),
          const _ManualDisasterTriggerPanel(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
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
// Active Disaster Live Card
// ─────────────────────────────────────────────────────────────────────────────

class _ActiveDisasterCard extends StatelessWidget {
  const _ActiveDisasterCard({required this.disaster, required this.tt});

  final ActiveDisaster disaster;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (disaster.phase) {
      DisasterPhase.warning => AppColors.sunrise,
      DisasterPhase.occurring => AppColors.coral,
      DisasterPhase.response => Colors.deepOrange,
      DisasterPhase.recovery => AppColors.teal,
      DisasterPhase.complete => Colors.green,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(20),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: statusColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(disaster.type.icon, color: statusColor, size: 28),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${disaster.severity.label} ${disaster.type.label}',
                      style: tt.titleMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      disaster.statusLabel,
                      style: tt.bodySmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  'Phase ${disaster.phase.name.toUpperCase()}',
                  style: tt.bodySmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Divider(color: statusColor.withAlpha(80), height: 1),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: [
              _MetricItem(
                label: 'Epicenter',
                value: '(${disaster.epicenterX}, ${disaster.epicenterY})',
                tt: tt,
              ),
              _MetricItem(
                label: 'Radius',
                value: disaster.radius > 0
                    ? '${disaster.radius.round()} tiles'
                    : 'City-wide',
                tt: tt,
              ),
              _MetricItem(
                label: 'Damaged Buildings',
                value: '${disaster.affectedBuildings.length}',
                tt: tt,
                valueColor: disaster.affectedBuildings.isNotEmpty
                    ? AppColors.coral
                    : null,
              ),
              _MetricItem(
                label: 'Blocked Roads',
                value: '${disaster.affectedRoads.length}',
                tt: tt,
                valueColor: disaster.affectedRoads.isNotEmpty
                    ? AppColors.coral
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.tt,
    this.valueColor,
  });

  final String label;
  final String value;
  final TextTheme tt;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: tt.bodySmall?.copyWith(color: AppColors.textSecondary)),
        Text(
          value,
          style: tt.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor ?? AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Risk Assessment Card
// ─────────────────────────────────────────────────────────────────────────────

class _RiskAssessmentCard extends StatelessWidget {
  const _RiskAssessmentCard({required this.risks, required this.tt});

  final Map<DisasterType, double> risks;
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
        children: DisasterType.values.map((type) {
          final mult = risks[type] ?? 1.0;
          final riskLevel = DisasterRiskLevel.fromMultiplier(mult);
          final progress = (mult / 3.0).clamp(0.1, 1.0);

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Icon(type.icon, size: 18, color: type.color),
                const SizedBox(width: AppSpacing.xs),
                SizedBox(
                  width: 90,
                  child: Text(
                    type.label,
                    style: tt.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.divider,
                      valueColor: AlwaysStoppedAnimation<Color>(riskLevel.color),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                SizedBox(
                  width: 60,
                  child: Text(
                    riskLevel.label,
                    textAlign: TextAlign.end,
                    style: tt.bodySmall?.copyWith(
                      color: riskLevel.color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notifications Tile
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.tt,
    required this.onDismiss,
  });

  final DisasterNotification notification;
  final TextTheme tt;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: notification.type.color.withAlpha(20),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: notification.type.color.withAlpha(100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(notification.type.icon,
              size: 20, color: notification.type.color),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: tt.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notification.message,
                  style: tt.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            onPressed: onDismiss,
            visualDensity: VisualDensity.compact,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// History View
// ─────────────────────────────────────────────────────────────────────────────

class _DisasterHistoryView extends StatelessWidget {
  const _DisasterHistoryView({required this.history, required this.tt});

  final List<DisasterReport> history;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.divider),
        ),
        child: Center(
          child: Text(
            'No disaster records in city history. City is stable.',
            style: tt.bodySmall?.copyWith(color: AppColors.teal),
          ),
        ),
      );
    }

    return Column(
      children: history.take(4).map((r) {
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.xs),
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(r.type.icon, size: 18, color: r.type.color),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      '${r.severity.label} ${r.type.label}',
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    '-¢${r.coinsLost}  •  -${r.happinessLost}% 🙂',
                    style: tt.bodySmall?.copyWith(
                      color: AppColors.coral,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                r.narrative,
                style: tt.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Manual Trigger Panel
// ─────────────────────────────────────────────────────────────────────────────

class _ManualDisasterTriggerPanel extends ConsumerStatefulWidget {
  const _ManualDisasterTriggerPanel();

  @override
  ConsumerState<_ManualDisasterTriggerPanel> createState() =>
      _ManualDisasterTriggerPanelState();
}

class _ManualDisasterTriggerPanelState
    extends ConsumerState<_ManualDisasterTriggerPanel> {
  DisasterSeverity _selectedSeverity = DisasterSeverity.moderate;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final buildings = ref.watch(cityBuildingsProvider).value ?? const [];
    final roadTiles = ref.watch(urbanSimulationProvider).roadGraph.roadTiles;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Intensity:',
                style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButton<DisasterSeverity>(
                  value: _selectedSeverity,
                  isDense: true,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: DisasterSeverity.values.map((s) {
                    return DropdownMenuItem(
                      value: s,
                      child: Text(s.label, style: tt.bodySmall),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedSeverity = val);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: DisasterType.values.map((type) {
              return ElevatedButton.icon(
                onPressed: () {
                  ref.read(disasterEngineProvider).triggerDisaster(
                        type,
                        severity: _selectedSeverity,
                        buildings: buildings,
                        roadTiles: roadTiles,
                      );
                },
                icon: Icon(type.icon, size: 16),
                label: Text(type.label),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: type.color,
                  elevation: 0,
                  side: BorderSide(color: AppColors.divider),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  visualDensity: VisualDensity.compact,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
