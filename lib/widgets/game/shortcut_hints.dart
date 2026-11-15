import 'package:flutter/material.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/widgets/game_card.dart';

/// Keyboard and mouse cheat sheet for the desktop side panel.
class ShortcutHints extends StatelessWidget {
  const ShortcutHints({super.key});

  static const _hints = <(String, String)>[
    ('Drag', 'Move the map'),
    ('Wheel', 'Zoom at cursor'),
    ('W A S D / Arrows', 'Move the map'),
    ('+ / -', 'Zoom'),
    ('Home', 'Show whole map'),
    ('G', 'Toggle grid'),
    ('Space', 'Pause / resume'),
    ('1 - 5', 'Open a section'),
    ('Esc', 'Deselect'),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return GameCard(
      key: const ValueKey('shortcut-hints'),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.keyboard_rounded,
                size: 18,
                color: AppColors.deepBlue,
              ),
              const SizedBox(width: AppSpacing.xs),
              Text('Controls', style: textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final (keys, action) in _hints)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  _KeyCap(label: keys),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      action,
                      style: textTheme.bodyMedium?.copyWith(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _KeyCap extends StatelessWidget {
  const _KeyCap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.divider),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.deepBlue,
          ),
        ),
      ),
    );
  }
}
