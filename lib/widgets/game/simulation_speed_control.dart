import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/models/simulation_speed.dart';
import 'package:city_builder_2040/providers/game_providers.dart';

/// Control buttons for pausing and adjusting simulation speed.
///
/// Supports full mode (play/pause and 1x/2x/3x pills for desktop) and compact
/// mode (play/pause button plus cyclable speed chip for mobile).
class SimulationSpeedControl extends ConsumerWidget {
  const SimulationSpeedControl({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(simulationSpeedProvider);
    final notifier = ref.read(simulationSpeedProvider.notifier);

    final pauseButton = _SpeedIconButton(
      icon: speed.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
      tooltip: speed.isPaused ? 'Resume simulation' : 'Pause simulation',
      selected: speed.isPaused,
      onPressed: notifier.togglePause,
    );

    if (compact) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          pauseButton,
          const SizedBox(width: AppSpacing.xxs),
          _CompactSpeedChip(
            speed: speed,
            onPressed: () {
              final next = switch (speed) {
                SimulationSpeed.paused => SimulationSpeed.normal,
                SimulationSpeed.normal => SimulationSpeed.fast,
                SimulationSpeed.fast => SimulationSpeed.superFast,
                SimulationSpeed.superFast => SimulationSpeed.normal,
              };
              notifier.setSpeed(next);
            },
          ),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.onDarkTrack,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            pauseButton,
            const SizedBox(width: AppSpacing.xxs),
            for (final s in const [
              SimulationSpeed.normal,
              SimulationSpeed.fast,
              SimulationSpeed.superFast,
            ]) ...[
              _SpeedPill(
                label: s.label,
                selected: speed == s,
                onPressed: () => notifier.setSpeed(s),
              ),
              if (s != SimulationSpeed.superFast)
                const SizedBox(width: AppSpacing.xxs),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpeedIconButton extends StatelessWidget {
  const _SpeedIconButton({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xs),
            child: Icon(
              icon,
              size: 20,
              color: selected ? AppColors.sunrise : AppColors.textOnDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedPill extends StatelessWidget {
  const _SpeedPill({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$label speed',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? AppColors.teal : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.navy : AppColors.textOnDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactSpeedChip extends StatelessWidget {
  const _CompactSpeedChip({required this.speed, required this.onPressed});

  final SimulationSpeed speed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Simulation speed: ${speed.label}',
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xs),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.onDarkTrack,
              borderRadius: BorderRadius.circular(AppRadius.xs),
            ),
            child: Text(
              speed.label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color:
                    speed.isPaused ? AppColors.sunrise : AppColors.textOnDark,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
