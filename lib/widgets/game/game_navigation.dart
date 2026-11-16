import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:city_builder_2040/core/constants/app_constants.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';
import 'package:city_builder_2040/models/game_section.dart';
import 'package:city_builder_2040/providers/game_providers.dart';

IconData gameSectionIcon(GameSection section) {
  return switch (section) {
    GameSection.build => Icons.apartment_rounded,
    GameSection.roads => Icons.add_road_rounded,
    GameSection.economy => Icons.account_balance_wallet_rounded,
    GameSection.missions => Icons.flag_rounded,
    GameSection.statistics => Icons.insights_rounded,
  };
}

enum GameNavStyle {
  /// Horizontal bar along the bottom edge (phones in portrait).
  bottomBar,

  /// Vertical rail along the left edge (landscape phones and desktop).
  rail,
}

/// Adaptive navigation between [GameSection]s.
///
/// With [alwaysOpen] false (phone) tapping the active item closes its panel.
/// With [alwaysOpen] true (desktop) one section is always shown, defaulting to
/// [GameSection.build].
class GameNavigation extends ConsumerWidget {
  const GameNavigation({
    super.key,
    required this.style,
    this.alwaysOpen = false,
  });

  final GameNavStyle style;
  final bool alwaysOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(activeSectionProvider);
    final current = alwaysOpen ? (open ?? GameSection.build) : open;
    final notifier = ref.read(activeSectionProvider.notifier);

    void onSelect(GameSection section) {
      if (alwaysOpen) {
        notifier.open(section);
      } else {
        notifier.toggle(section);
      }
    }

    final items = [
      for (final section in GameSection.values)
        _NavItem(
          section: section,
          selected: section == current,
          vertical: style == GameNavStyle.rail,
          onTap: () => onSelect(section),
        ),
    ];

    return switch (style) {
      GameNavStyle.bottomBar => ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Color(0xF5061A3A),
                  Color(0xD9061A3A),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 16,
                  offset: Offset(0, -4),
                ),
              ],
              border: Border(
                top: BorderSide(
                  color: AppColors.aqua.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.xs,
                ),
                child: Row(
                  children: [for (final item in items) Expanded(child: item)],
                ),
              ),
            ),
          ),
        ),
      ),
      GameNavStyle.rail => ClipRRect(
        borderRadius: const BorderRadius.horizontal(
          right: Radius.circular(AppRadius.md),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color(0xF5061A3A),
                  Color(0xD9061A3A),
                ],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x40000000),
                  blurRadius: 12,
                  offset: Offset(4, 0),
                ),
              ],
              border: Border(
                right: BorderSide(
                  color: AppColors.aqua.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              right: false,
              child: SizedBox(
                width: 88,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: AppSpacing.sm,
                  ),
                  child: Column(
                    children: [
                      for (final item in items) ...[
                        item,
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    };
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.section,
    required this.selected,
    required this.vertical,
    required this.onTap,
  });

  final GameSection section;
  final bool selected;
  final bool vertical;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? AppColors.navy : AppColors.textOnDark;
    final radius = BorderRadius.circular(AppRadius.md);

    return Semantics(
      button: true,
      selected: selected,
      label: section.label,
      excludeSemantics: true,
      child: Tooltip(
        message: section.label,
        child: AnimatedContainer(
          duration: AppConstants.fastAnimation,
          decoration: BoxDecoration(
            gradient: selected ? AppColors.tealGradient : null,
            borderRadius: radius,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              key: ValueKey('nav-${section.name}'),
              borderRadius: radius,
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs,
                    vertical: vertical ? AppSpacing.sm : AppSpacing.xxs,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(gameSectionIcon(section), color: foreground),
                      const SizedBox(height: 2),
                      Text(
                        section.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: foreground,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
