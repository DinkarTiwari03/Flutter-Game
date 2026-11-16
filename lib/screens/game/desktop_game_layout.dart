import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/game/engine/map_camera_controller.dart';
import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/models/game_section.dart';
import 'package:city_builder_2040/providers/building_providers.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/widgets/game/building_inspector_panel.dart';
import 'package:city_builder_2040/widgets/game/desktop_top_bar.dart';
import 'package:city_builder_2040/widgets/game/game_navigation.dart';
import 'package:city_builder_2040/widgets/game/map_controls.dart';
import 'package:city_builder_2040/widgets/game/map_viewport.dart';
import 'package:city_builder_2040/widgets/game/placement_hud.dart';
import 'package:city_builder_2040/widgets/game/section_panel.dart';
import 'package:city_builder_2040/widgets/game/shortcut_hints.dart';
import 'package:city_builder_2040/widgets/game/tile_info_panel.dart';

/// Desktop layout: resource dashboard on top; below it a navigation rail, a
/// section (building selection) panel, the large map viewport, and an
/// inspection panel with keyboard hints on the right.
class DesktopGameLayout extends ConsumerWidget {
  const DesktopGameLayout({
    super.key,
    required this.map,
    required this.controller,
    required this.focusNode,
    required this.viewportKey,
  });

  static const panelWidth = 300.0;

  final GameMap map;
  final MapCameraController controller;
  final FocusNode focusNode;
  final GlobalKey viewportKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(activeSectionProvider) ?? GameSection.build;

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1, 2 & side components: Map with side panels ──
          Positioned.fill(
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 84.0),
                  child: GameNavigation(
                    style: GameNavStyle.rail,
                    alwaysOpen: true,
                  ),
                ),
                SizedBox(
                  width: panelWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 84.0),
                    child: SectionSidePanel(section: section),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: MapViewport(
                          key: viewportKey,
                          map: map,
                          controller: controller,
                          focusNode: focusNode,
                        ),
                      ),
                      Positioned(
                        right: AppSpacing.md,
                        bottom: AppSpacing.md,
                        child: MapControls(controller: controller),
                      ),
                      if (ref.watch(placementProvider).isPlacing)
                        Positioned(
                          left: AppSpacing.lg,
                          right: AppSpacing.lg,
                          bottom: AppSpacing.md,
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: const PlacementHud(),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(
                  width: panelWidth,
                  child: Padding(
                    padding: EdgeInsets.only(top: 84.0),
                    child: _InspectorPanel(),
                  ),
                ),
              ],
            ),
          ),

          // ── Layer 4: Floating Top HUD overlay ──
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: DesktopTopBar(),
          ),
        ],
      ),
    );
  }
}

class _InspectorPanel extends ConsumerWidget {
  const _InspectorPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(selectedTileInfoProvider);
    final selectedBuilding = ref.watch(selectedBuildingProvider);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(left: BorderSide(color: AppColors.divider)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (selectedBuilding != null)
              BuildingInspectorPanel(
                building: selectedBuilding,
                onClose: ref.read(selectedBuildingIdProvider.notifier).clear,
              )
            else
              TileInfoSidebar(
                info: info,
                onClose:
                    info == null
                        ? null
                        : ref.read(selectedTileProvider.notifier).clear,
              ),
            const SizedBox(height: AppSpacing.md),
            const ShortcutHints(),
          ],
        ),
      ),
    );
  }
}
