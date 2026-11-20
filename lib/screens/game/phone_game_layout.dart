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
    final topHudHeight =
        CompactTopBar.totalHeight(context, singleRow: landscape);
    // Responsive vertical gap of 18 logical pixels (within the 16–20px range)
    // between the bottom of the top HUD and the top of the plus (+) zoom button.
    const verticalGap = 18.0;
    final controlsTop = topHudHeight + verticalGap;

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1 & 2: Full-screen isometric world and terrain ──
          Positioned.fill(
            child: MapViewport(
              key: viewportKey,
              map: map,
              controller: controller,
              focusNode: focusNode,
            ),
          ),

          // ── Layer 3: Camera controls (zoom, reset camera, grid toggle) ──
          Positioned(
            top: controlsTop,
            right: AppSpacing.md,
            child: SafeArea(
              top: false,
              bottom: true,
              left: false,
              right: true,
              child: MapControls(controller: controller),
            ),
          ),

          // ── Contextual floating panels (Placement HUD, Inspector, Section Sheet, Tile Info) ──
          Positioned.fill(
            child: _FloatingPanels(landscape: landscape),
          ),

          // ── Layer 4: Top HUD overlay (Clash of Clans style) ──
          Positioned(
            top: 0,
            left: landscape ? 88.0 : 0,
            right: 0,
            child: CompactTopBar(singleRow: landscape),
          ),

          // ── Layer 5: Bottom / Rail Navigation overlay ──
          if (landscape)
            const Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              child: GameNavigation(style: GameNavStyle.rail),
            )
          else
            const Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: GameNavigation(style: GameNavStyle.bottomBar),
            ),
        ],
      ),
    );
  }
}

class _FloatingPanels extends ConsumerWidget {
  const _FloatingPanels({required this.landscape});

  final bool landscape;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(activeSectionProvider);
    final info = ref.watch(selectedTileInfoProvider);
    final selectedBuilding = ref.watch(selectedBuildingProvider);
    final placement = ref.watch(placementProvider);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Vertical and horizontal clearance ensuring panels sit comfortably
        // between the floating top HUD and bottom navigation.
        final topClearance =
            CompactTopBar.totalHeight(context, singleRow: landscape) +
            AppSpacing.xs;
        final bottomClearance = landscape ? AppSpacing.md : 75.0;
        final leftClearance =
            landscape ? (88.0 + AppSpacing.md) : AppSpacing.md;

        final availableHeight =
            constraints.maxHeight - topClearance - bottomClearance;

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
            maxHeight: availableHeight > 120 ? availableHeight : 200,
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

        return Padding(
          padding: EdgeInsets.fromLTRB(
            leftClearance,
            topClearance,
            AppSpacing.md,
            bottomClearance,
          ),
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
        );
      },
    );
  }
}
