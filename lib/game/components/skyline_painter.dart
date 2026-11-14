import 'package:flutter/material.dart';

/// Decorative two-layer night skyline drawn along the bottom edge.
class SkylinePainter extends CustomPainter {
  const SkylinePainter();

  static const _backHeights = <double>[
    0.55, 0.8, 0.45, 0.95, 0.6, 0.7, 0.5, 0.85, 0.65, 0.75, //
  ];
  static const _frontHeights = <double>[
    0.4, 0.65, 0.5, 0.85, 0.45, 0.7, 0.55, 0.6, //
  ];

  static const _backColor = Color(0x330B6E8A);
  static const _frontColor = Color(0xFF071F45);
  static const _windowTeal = Color(0xB32DD4BF);
  static const _windowAmber = Color(0xB3FFB547);

  @override
  void paint(Canvas canvas, Size size) {
    _paintLayer(
      canvas,
      size,
      heights: _backHeights,
      maxHeightFactor: 0.42,
      color: _backColor,
      withWindows: false,
    );
    _paintLayer(
      canvas,
      size,
      heights: _frontHeights,
      maxHeightFactor: 0.30,
      color: _frontColor,
      withWindows: true,
    );
  }

  void _paintLayer(
    Canvas canvas,
    Size size, {
    required List<double> heights,
    required double maxHeightFactor,
    required Color color,
    required bool withWindows,
  }) {
    final paint = Paint()..color = color;
    final windowPaint = Paint();
    final slot = size.width / heights.length;
    final maxHeight = size.height * maxHeightFactor;

    for (var i = 0; i < heights.length; i++) {
      final height = maxHeight * heights[i];
      final rect = Rect.fromLTWH(
        i * slot + slot * 0.06,
        size.height - height,
        slot * 0.88,
        height,
      );
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        paint,
      );
      if (withWindows) _paintWindows(canvas, rect, i, windowPaint);
    }
  }

  void _paintWindows(Canvas canvas, Rect tower, int seed, Paint paint) {
    const gap = 10.0;
    const windowSize = 4.0;
    final cols = ((tower.width - 12) / gap).floor();
    final rows = ((tower.height - 16) / gap).floor();

    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        if ((r * 7 + c * 13 + seed * 5) % 5 >= 2) continue;
        paint.color = (r + c + seed) % 4 == 0 ? _windowAmber : _windowTeal;
        canvas.drawRect(
          Rect.fromLTWH(
            tower.left + 8 + c * gap,
            tower.top + 10 + r * gap,
            windowSize,
            windowSize,
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant SkylinePainter oldDelegate) => false;
}
