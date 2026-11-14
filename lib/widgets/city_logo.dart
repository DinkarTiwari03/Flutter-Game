import 'package:flutter/material.dart';
import 'package:city_builder_2040/core/constants/app_constants.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';

class CityLogo extends StatelessWidget {
  const CityLogo({super.key, this.size = 88});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.tealGradient,
        borderRadius: BorderRadius.circular(size * 0.3),
        boxShadow: const [
          BoxShadow(
            color: AppColors.tealGlow,
            blurRadius: 28,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Icon(
        Icons.location_city_rounded,
        size: size * 0.55,
        color: AppColors.navy,
      ),
    );
  }
}

class GameTitle extends StatelessWidget {
  const GameTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      label: AppConstants.appName,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CITY BUILDER',
              style: textTheme.titleMedium?.copyWith(
                color: AppColors.aqua,
                fontWeight: FontWeight.w700,
                letterSpacing: 6,
              ),
            ),
            ShaderMask(
              shaderCallback: (bounds) =>
                  AppColors.titleGradient.createShader(bounds),
              child: Text(
                '2040',
                style: textTheme.displayLarge?.copyWith(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
