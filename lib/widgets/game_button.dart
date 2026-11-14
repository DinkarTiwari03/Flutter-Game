import 'package:flutter/material.dart';
import 'package:city_builder_2040/core/constants/app_constants.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/core/theme/app_spacing.dart';

enum GameButtonVariant { primary, secondary }

class GameButton extends StatefulWidget {
  const GameButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.variant = GameButtonVariant.primary,
    this.expand = true,
  });

  final String label;

  /// Passing null renders the button in its disabled state.
  final VoidCallback? onPressed;
  final IconData? icon;
  final GameButtonVariant variant;
  final bool expand;

  @override
  State<GameButton> createState() => _GameButtonState();
}

class _GameButtonState extends State<GameButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  @override
  Widget build(BuildContext context) {
    final style = _ButtonStyle.resolve(widget.variant, enabled: _enabled);
    final radius = BorderRadius.circular(AppRadius.md);
    final textStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
          color: style.foreground,
        );

    return Semantics(
      button: true,
      enabled: _enabled,
      child: AnimatedScale(
        scale: _pressed && _enabled ? 0.97 : 1,
        duration: AppConstants.fastAnimation,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: style.background,
            gradient: style.gradient,
            borderRadius: radius,
            border: style.border,
            boxShadow: style.shadows,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: radius,
              onTap: widget.onPressed,
              onHighlightChanged: (value) => setState(() => _pressed = value),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.sm,
                  ),
                  child: Row(
                    mainAxisSize:
                        widget.expand ? MainAxisSize.max : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(widget.icon, color: style.foreground, size: 22),
                        const SizedBox(width: AppSpacing.xs),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          style: textStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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

class _ButtonStyle {
  const _ButtonStyle({
    required this.foreground,
    this.background,
    this.gradient,
    this.border,
    this.shadows = const [],
  });

  final Color foreground;
  final Color? background;
  final Gradient? gradient;
  final BoxBorder? border;
  final List<BoxShadow> shadows;

  static _ButtonStyle resolve(
    GameButtonVariant variant, {
    required bool enabled,
  }) {
    if (!enabled) {
      return const _ButtonStyle(
        foreground: AppColors.disabledForeground,
        background: AppColors.disabledSurface,
      );
    }
    return switch (variant) {
      GameButtonVariant.primary => const _ButtonStyle(
          foreground: AppColors.navy,
          gradient: AppColors.tealGradient,
          shadows: [
            BoxShadow(
              color: AppColors.tealGlow,
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
      GameButtonVariant.secondary => const _ButtonStyle(
          foreground: AppColors.deepBlue,
          background: AppColors.surface,
          border: Border.fromBorderSide(BorderSide(color: AppColors.divider)),
        ),
    };
  }
}
