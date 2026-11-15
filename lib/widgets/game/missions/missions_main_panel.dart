import 'package:flutter/material.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/widgets/game/missions/achievements_panel.dart';
import 'package:city_builder_2040/widgets/game/missions/challenges_panel.dart';
import 'package:city_builder_2040/widgets/game/missions/missions_panel.dart';
import 'package:city_builder_2040/widgets/game/missions/progression_panel.dart';

class MissionsMainPanel extends StatefulWidget {
  const MissionsMainPanel({super.key});

  @override
  State<MissionsMainPanel> createState() => _MissionsMainPanelState();
}

class _MissionsMainPanelState extends State<MissionsMainPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Missions'),
            Tab(text: 'Challenges'),
            Tab(text: 'Achievements'),
            Tab(text: 'Progression'),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: 480,
          child: TabBarView(
            controller: _tabController,
            children: const [
              MissionsPanel(),
              ChallengesPanel(),
              AchievementsPanel(),
              ProgressionPanel(),
            ],
          ),
        ),
      ],
    );
  }
}
