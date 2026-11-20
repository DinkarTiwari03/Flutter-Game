import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/game/engine/map_camera_controller.dart';
import 'package:city_builder_2040/game/map/game_map.dart';
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

/// Desktop layout: bounded top resource bar; below it a navigation rail, an
/// optional tool/section panel on the left, the expansive map viewport in the
/// middle, and a toggleable inspector & shortcut hints panel on the right.
///
/// Neither the top dashboard nor side panels overlap the city map.
class DesktopGameLayout extends ConsumerWidget {
  const DesktopGameLayout({
    super.key,
    required this.map,
    required this.controller,
    required this.focusNode,
    required this.viewportKey,
  });

  final GameMap map;
  final MapCameraController controller;
  final FocusNode focusNode;
  final GlobalKey viewportKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final section = ref.watch(activeSectionProvider);
    final isExplicitlyOpen = ref.watch(desktopInspectorVisibleProvider);
    final hasSelection = ref.watch(selectedBuildingProvider) != null ||
        ref.watch(selectedTileProvider) != null;
    final showInspector = isExplicitlyOpen || hasSelection;

    return Scaffold(
      backgroundColor: AppColors.navy,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;

          // Responsive panel width scaling with window resolution
          final panelWidth = (totalWidth * 0.22).clamp(260.0, 320.0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top Bar: Resource Dashboard (bounded, non-overlapping) ──
              const DesktopTopBar(),

              // ── Main Gameplay Workspace ──
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Navigation Rail (tools can be selected / deselected) ──
                    const GameNavigation(
                      style: GameNavStyle.rail,
                      alwaysOpen: false,
                    ),

                    // ── Section Side Panel (Build, Roads, Economy, Missions, Stats) ──
                    if (section != null)
                      SizedBox(
                        width: panelWidth,
                        child: SectionSidePanel(
                          section: section,
                          onClose: () =>
                              ref.read(activeSectionProvider.notifier).close(),
                        ),
                      ),

                    // ── Center Map Viewport (occupies all remaining space) ──
                    Expanded(
                      child: ClipRect(
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
                            // Floating Camera Controls (Reset camera, Grid toggle)
                            Positioned(
                              right: AppSpacing.md,
                              bottom: AppSpacing.md,
                              child: MapControls(controller: controller),
                            ),
                            // Toggle button to show/hide the right Keys & Inspector panel
                            Positioned(
                              top: AppSpacing.md,
                              right: AppSpacing.md,
                              child: _PanelToggleButton(
                                isOpen: showInspector,
                                onToggle: () {
                                  if (showInspector) {
                                    ref
                                        .read(selectedBuildingIdProvider.notifier)
                                        .clear();
                                    ref
                                        .read(selectedTileProvider.notifier)
                                        .clear();
                                    ref
                                        .read(desktopInspectorVisibleProvider
                                            .notifier)
                                        .hide();
                                  } else {
                                    ref
                                        .read(desktopInspectorVisibleProvider
                                            .notifier)
                                        .show();
                                  }
                                },
                              ),
                            ),
                            // Placement HUD overlay during active construction
                            if (ref.watch(placementProvider).isPlacing)
                              Positioned(
                                left: AppSpacing.lg,
                                right: AppSpacing.lg,
                                bottom: AppSpacing.md,
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(maxWidth: 440),
                                    child: const PlacementHud(),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),

                    // ── Right-Side Keys / Inspector Panel (Toggleable) ──
                    if (showInspector)
                      SizedBox(
                        width: panelWidth,
                        child: _InspectorPanel(
                          onClose: () {
                            ref
                                .read(selectedBuildingIdProvider.notifier)
                                .clear();
                            ref.read(selectedTileProvider.notifier).clear();
                            ref
                                .read(desktopInspectorVisibleProvider.notifier)
                                .hide();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Floating toggle button positioned on the map to show/hide the right panel.
class _PanelToggleButton extends StatelessWidget {
  const _PanelToggleButton({
    required this.isOpen,
    required this.onToggle,
  });

  final bool isOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isOpen
          ? 'Hide Controls & Info panel (H)'
          : 'Show Controls & Info panel (H)',
      child: Material(
        color:
            isOpen ? AppColors.teal : AppColors.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        elevation: 3,
        shadowColor: AppColors.cardShadow,
        child: InkWell(
          key: const ValueKey('btn-map-toggle-inspector'),
          borderRadius: BorderRadius.circular(AppRadius.sm),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.keyboard_rounded,
                  size: 16,
                  color: isOpen ? AppColors.navy : AppColors.textOnDark,
                ),
                const SizedBox(width: 6),
                Text(
                  'Controls',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isOpen ? AppColors.navy : AppColors.textOnDark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InspectorPanel extends ConsumerWidget {
  const _InspectorPanel({this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(selectedTileInfoProvider);
    final selectedBuilding = ref.watch(selectedBuildingProvider);
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(left: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with Title & Close button
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.sm,
              AppSpacing.sm,
              AppSpacing.xs,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppColors.teal,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    selectedBuilding != null
                        ? 'Building Details'
                        : (info != null ? 'Tile Inspector' : 'Info & Controls'),
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onClose != null)
                  IconButton(
                    key: const ValueKey('btn-close-inspector'),
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Hide panel',
                    onPressed: onClose,
                    constraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    padding: EdgeInsets.zero,
                  ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          // Scrollable content area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (selectedBuilding != null)
                    BuildingInspectorPanel(
                      building: selectedBuilding,
                      onClose:
                          ref.read(selectedBuildingIdProvider.notifier).clear,
                    )
                  else
                    TileInfoSidebar(
                      info: info,
                      onClose: info == null
                          ? null
                          : ref.read(selectedTileProvider.notifier).clear,
                    ),
                  const SizedBox(height: AppSpacing.md),
                  const ShortcutHints(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
