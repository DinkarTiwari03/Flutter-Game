import 'package:flutter/material.dart';

/// Colors used when painting the isometric map.
abstract final class MapColors {
  // Outside the map.
  static const outside = Color(0xFF0A2347);

  // Grass (picked per tile for a subtle patchwork).
  static const grassShades = <Color>[
    Color(0xFF86D66B),
    Color(0xFF7ECF64),
    Color(0xFF8DDB72),
    Color(0xFF78C960),
  ];
  static const grassTuft = Color(0xFF5CAE49);

  // Sand and shoreline.
  static const sandShades = <Color>[Color(0xFFF3DEA2), Color(0xFFEFD797)];
  static const sandSpeck = Color(0xFFD9BE7C);

  // Water.
  static const waterShades = <Color>[
    Color(0xFF3AA9E0),
    Color(0xFF35A0D8),
    Color(0xFF3FB1E6),
  ];
  static const waterWave = Color(0x66FFFFFF);
  static const waterFoam = Color(0x99FFFFFF);

  // Roads.
  static const asphalt = Color(0xFF4B5563);
  static const kerb = Color(0xFFB6BDC8);
  static const laneMarking = Color(0xFFFDE68A);

  // Decorations.
  static const shadow = Color(0x26000000);
  static const trunk = Color(0xFF7C4A21);
  static const canopyDark = Color(0xFF2A8A4C);
  static const canopyMid = Color(0xFF34A35A);
  static const canopyLight = Color(0xFF4CC070);
  static const pineDark = Color(0xFF1C6E47);
  static const pineMid = Color(0xFF268A57);
  static const bush = Color(0xFF3FAE5F);
  static const rockLight = Color(0xFFB4BBC6);
  static const rockDark = Color(0xFF7B8493);
  static const flowerColors = <Color>[
    Color(0xFFFF6B6B),
    Color(0xFFFFB547),
    Color(0xFFFFFFFF),
    Color(0xFFB794F4),
  ];

  // Overlays.
  static const grid = Color(0x24FFFFFF);
  static const hoverFill = Color(0x2EFFFFFF);
  static const hoverStroke = Color(0x99FFFFFF);
  static const selectionFill = Color(0x592DD4BF);
  static const selectionStroke = Color(0xFF2DD4BF);
  static const selectionGlow = Color(0x662DD4BF);
}
