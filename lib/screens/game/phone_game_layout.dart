import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/constants/app_constants.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/game/engine/map_camera_controller.dart';
import 'package:city_builder_2040/game/map/game_map.dart';
import 'package:city_builder_2040/providers/building_providers.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/widgets/game/building_inspector_panel.dart';
import 'package:city_builder_2040/widgets/game/compact_top_bar.dart';
import 'package:city_builder_2040/widgets/game/game_navigation.dart';
import 'package:city_builder_2040/widgets/game/map_controls.dart';
import 'package:city_builder_2040/widgets/game/map_viewport.dart';
import 'package:city_builder_2040/widgets/game/placement_hud.dart';
import 'package:city_builder_2040/widgets/game/section_panel.dart';
import 'package:city_builder_2040/widgets/game/tile_info_panel.dart';

/// Touch-first layout: compact resource bar, the map filling the screen, and
/// floating panels for the selected tile or the open section.
///
/// In portrait the navigation is a bottom bar; in landscape ([landscape])
/// it becomes a left rail so the map keeps its height.
class PhoneGameLayout extends StatelessWidget {
  const PhoneGameLayout({
    super.key,
    required this.map,
    required this.controller,
    required this.focusNode,
    required this.viewportKey,
    this.landscape = false,
  });

  final GameMap map;
  final MapCameraController controller;
  final FocusNode focusNode;
  final GlobalKey viewportKey;
  final bool landscape;

  @override
  Widget build(BuildContext context) {
    final mapArea = _MapArea(
      map: map,
      controller: controller,
      focusNode: focusNode,
      viewportKey: viewportKey,
      landscape: landscape,
    );

    return Scaffold(
      backgroundColor: AppColors.navy,
      body:
          landscape
              ? Row(
                children: [
                  const GameNavigation(style: GameNavStyle.rail),
                  Expanded(
                    child: Column(
                      children: [
                        const CompactTopBar(singleRow: true),
                        Expanded(child: mapArea),
                      ],
                    ),
                  ),
                ],
              )
              : Column(
                children: [
                  const CompactTopBar(),
                  Expanded(child: mapArea),
                  const GameNavigation(style: GameNavStyle.bottomBar),
                ],
              ),
    );
  }
}

class _MapArea extends ConsumerWidget {
  const _MapArea({
    required this.map,
    required this.controller,
    required this.focusNode,
    required this.viewportKey,
    required this.landscape,
  });

  final GameMap map;
  final MapCameraController controller;
  final FocusNode focusNode;
  final GlobalKey viewportKey;
  final bool landscape;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(activeSectionProvider);
    final info = ref.watch(selectedTileInfoProvider);
    final selectedBuilding = ref.watch(selectedBuildingProvider);
    final placement = ref.watch(placementProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        final Widget panel;
        if (placement.isPlacing) {
          panel = const PlacementHud();
        } else if (selectedBuilding != null) {
          panel = BuildingInspectorPanel(
            building: selectedBuilding,
            onClose: ref.read(selectedBuildingIdProvider.notifier).clear,
          );
        } else if (section != null) {
          panel = SectionSheet(
            section: section,
            maxHeight: constraints.maxHeight - AppSpacing.md * 2,
            onClose: ref.read(activeSectionProvider.notifier).close,
          );
        } else if (info != null) {
          panel = TileInfoCard(
            info: info,
            onClose: ref.read(selectedTileProvider.notifier).clear,
          );
        } else {
          panel = const SizedBox.shrink();
        }

        return Stack(
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
              top: AppSpacing.md,
              right: AppSpacing.md,
              child: MapControls(controller: controller),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Align(
                  alignment:
                      landscape ? Alignment.bottomLeft : Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: landscape ? 380 : 520,
                    ),
                    child: AnimatedSwitcher(
                      duration: AppConstants.mediumAnimation,
                      switchInCurve: Curves.easeOutCubic,
                      transitionBuilder:
                          (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.15),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          ),
                      child: panel,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
