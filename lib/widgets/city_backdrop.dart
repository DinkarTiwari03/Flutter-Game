import 'package:flutter/material.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/game/components/skyline_painter.dart';

/// Deep-blue gradient with a painted skyline, used behind splash and menu.
class CityBackdrop extends StatelessWidget {
  const CityBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: AppColors.skyGradient),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: SkylinePainter()),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
