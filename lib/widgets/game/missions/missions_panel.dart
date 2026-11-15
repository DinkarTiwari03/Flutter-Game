import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/providers/progression_providers.dart';
import 'package:city_builder_2040/widgets/game/missions/mission_card.dart';

class MissionsPanel extends ConsumerStatefulWidget {
  const MissionsPanel({super.key});

  @override
  ConsumerState<MissionsPanel> createState() => _MissionsPanelState();
}

class _MissionsPanelState extends ConsumerState<MissionsPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Trigger evaluation when panel opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(cityMissionProgressProvider.notifier).evaluateAll();
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TabBar(
          controller: _tabController,
          labelColor: AppColors.teal,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.teal,
          tabs: const [
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 380,
          child: TabBarView(
            controller: _tabController,
            children: const [
              _MissionList(filterCompleted: false),
              _MissionList(filterCompleted: true),
            ],
          ),
        ),
      ],
    );
  }
}

class _MissionList extends ConsumerWidget {
  const _MissionList({required this.filterCompleted});
  final bool filterCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allProgress = ref.watch(cityMissionProgressProvider).value ?? [];
    final progressMap = {for (final p in allProgress) p.missionId: p};

    final missions = filterCompleted
        ? ref.watch(completedMissionsProvider)
        : ref.watch(activeMissionsProvider);

    if (missions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              filterCompleted
                  ? Icons.emoji_events_rounded
                  : Icons.assignment_rounded,
              size: 48,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              filterCompleted
                  ? 'No completed missions yet'
                  : 'No active missions',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: missions.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, i) {
        final mission = missions[i];
        return MissionCard(
          mission: mission,
          progress: progressMap[mission.id],
        );
      },
    );
  }
}
