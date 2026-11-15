import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/game/engine/map_camera_controller.dart';
import 'package:city_builder_2040/providers/game_providers.dart';

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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ControlButton(
          buttonKey: const ValueKey('control-zoom-in'),
          icon: Icons.add_rounded,
          tooltip: 'Zoom in (+)',
          onPressed: controller.zoomIn,
        ),
        const SizedBox(height: AppSpacing.xs),
        _ControlButton(
          buttonKey: const ValueKey('control-zoom-out'),
          icon: Icons.remove_rounded,
          tooltip: 'Zoom out (-)',
          onPressed: controller.zoomOut,
        ),
        const SizedBox(height: AppSpacing.xs),
        _ControlButton(
          buttonKey: const ValueKey('control-fit'),
          icon: Icons.fit_screen_rounded,
          tooltip: 'Show whole map (Home)',
          onPressed: controller.showWholeMap,
        ),
        const SizedBox(height: AppSpacing.xs),
        _ControlButton(
          buttonKey: const ValueKey('control-grid'),
          icon: Icons.grid_4x4_rounded,
          tooltip: 'Toggle grid (G)',
          selected: showGrid,
          onPressed: ref.read(showGridProvider.notifier).toggle,
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
  });

  final Key buttonKey;
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool selected;

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
                width: 48,
                height: 48,
                child: Icon(
                  icon,
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
