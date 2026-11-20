import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/game/engine/map_camera_controller.dart';
import 'package:city_builder_2040/providers/game_providers.dart';
import 'package:city_builder_2040/providers/urban_providers.dart';

/// Floating zoom / recenter / grid buttons over the map.
///
/// Gives touch users (and anyone without a wheel or pinch) the same camera
/// commands that gestures and keyboard shortcuts provide.
class MapControls extends ConsumerWidget {
  const MapControls({super.key, required this.controller});

  final MapCameraController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showGrid = ref.watch(showGridProvider);
    final showTrafficHeatmap = ref.watch(trafficHeatmapVisibleProvider);
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final btnSize = isLandscape ? 40.0 : 44.0;
    final iconSize = isLandscape ? 20.0 : 22.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ControlButton(
          buttonKey: const ValueKey('control-fit'),
          icon: Icons.explore_rounded,
          tooltip: 'Reset camera (Home)',
          size: btnSize,
          iconSize: iconSize,
          onPressed: controller.resetCamera,
        ),
        const SizedBox(height: AppSpacing.xs),
        _ControlButton(
          buttonKey: const ValueKey('control-grid'),
          icon: Icons.grid_4x4_rounded,
          tooltip: 'Toggle grid (G)',
          selected: showGrid,
          size: btnSize,
          iconSize: iconSize,
          onPressed: ref.read(showGridProvider.notifier).toggle,
        ),
        const SizedBox(height: AppSpacing.xs),
        _ControlButton(
          buttonKey: const ValueKey('control-traffic'),
          icon: Icons.traffic_rounded,
          tooltip: 'Traffic heatmap (T)',
          selected: showTrafficHeatmap,
          size: btnSize,
          iconSize: iconSize,
          onPressed: ref.read(trafficHeatmapVisibleProvider.notifier).toggle,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  const _ControlButton({
    required this.buttonKey,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.selected = false,
    this.size = 44.0,
    this.iconSize = 22.0,
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.sm);
    return Semantics(
      button: true,
      label: tooltip,
      selected: selected,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected ? AppColors.teal : AppColors.surface,
            borderRadius: radius,
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: buttonKey,
              borderRadius: radius,
              onTap: onPressed,
              child: SizedBox(
                width: size,
                height: size,
                child: Icon(
                  icon,
                  size: iconSize,
                  color: selected ? Colors.white : AppColors.deepBlue,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
