import 'package:flutter/material.dart';

abstract final class AppColors {
  // Brand
  static const navy = Color(0xFF061A3A);
  static const deepBlue = Color(0xFF0B2A5B);
  static const royalBlue = Color(0xFF1746A2);
  static const teal = Color(0xFF14B8A6);
  static const aqua = Color(0xFF2DD4BF);
  static const sky = Color(0xFF38BDF8);
  static const sunrise = Color(0xFFFFB547);
  static const coral = Color(0xFFFF6B6B);

  // Surfaces and text
  static const background = Color(0xFFF3F8FB);
  static const surface = Color(0xFFFFFFFF);
  static const divider = Color(0xFFDCE7EF);
  static const textPrimary = Color(0xFF0F1F3D);
  static const textSecondary = Color(0xFF5B6B86);
  static const textOnDark = Color(0xFFF2F8FF);

  // Disabled (readable on both dark and light backgrounds)
  static const disabledSurface = Color(0x338A9BB5);
  static const disabledForeground = Color(0xFF8A9BB5);

  // Shadows and overlays
  static const tealGlow = Color(0x6614B8A6);
  static const cardShadow = Color(0x140B2A5B);
  static const onDarkTrack = Color(0x33FFFFFF);

  // Gradients
  static const skyGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [navy, deepBlue, Color(0xFF0E5E7A)],
  );
  static const tealGradient = LinearGradient(colors: [teal, aqua]);
  static const titleGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), aqua],
  );
}
