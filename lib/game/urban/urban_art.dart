import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:city_builder_2040/core/theme/app_colors.dart';
import 'package:city_builder_2040/game/urban/compass_direction.dart';
import 'package:city_builder_2040/game/urban/pedestrian.dart';
import 'package:city_builder_2040/game/urban/urban_sprite_cache.dart';
import 'package:city_builder_2040/game/urban/urban_sprite_registry.dart';
import 'package:city_builder_2040/game/urban/vehicle.dart';

/// Isometric 2.5D visual rendering routines for vehicles, pedestrians, and traffic lights.
abstract final class UrbanArt {
  /// Paints a moving vehicle at its world position, applying directional sprite
  /// and night lighting where applicable.
  static void paintVehicle({
    required Canvas canvas,
    required Vehicle vehicle,
    required UrbanSpriteCache cache,
    required bool isNight,
    required VoidCallback onSpriteLoaded,
  }) {
    final assetPath = UrbanSpriteRegistry.vehicleAsset(vehicle.type, vehicle.heading);
    cache.warmUp(assetPath, onLoaded: onSpriteLoaded);
    final sprite = cache.get(assetPath);

    // 1. Headlights and taillights during night and dusk
    if (isNight) {
      _paintVehicleLights(canvas, vehicle);
    }

    // 2. Sprite drawing
    if (sprite != null) {
      final w = sprite.width.toDouble();
      final h = sprite.height.toDouble();

      final dst = Rect.fromLTWH(
        vehicle.worldPos.dx - w / 2,
        vehicle.worldPos.dy - h * 0.85,
        w,
        h,
      );
      final src = Rect.fromLTWH(0, 0, w, h);

      canvas.drawImageRect(
        sprite,
        src,
        dst,
        Paint()..isAntiAlias = true,
      );
    } else {
      _paintProceduralVehicle(canvas, vehicle);
    }
  }

  /// Paints night headlights and taillights.
  static void _paintVehicleLights(Canvas canvas, Vehicle v) {
    final fwd = switch (v.heading) {
      CompassDirection.se => const Offset(28.0, 14.0),
      CompassDirection.sw => const Offset(-28.0, 14.0),
      CompassDirection.nw => const Offset(-28.0, -14.0),
      CompassDirection.ne => const Offset(28.0, -14.0),
    };

    final headlightCenter = v.worldPos + fwd * 0.45;

    // Headlight radial beam
    final lightPaint = Paint()
      ..shader = ui.Gradient.radial(
        headlightCenter,
        22.0,
        [
          const Color(0x80FFFFD0),
          const Color(0x25FFFFD0),
          const Color(0x00FFFFD0),
        ],
        [0.0, 0.45, 1.0],
      );
    canvas.drawCircle(headlightCenter, 22.0, lightPaint);

    // Taillight glow on rear
    final rearCenter = v.worldPos - fwd * 0.40;
    canvas.drawCircle(
      rearCenter,
      2.8,
      Paint()..color = const Color(0xDDFF3333),
    );
  }

  /// Procedural fallback when vehicle sprite is loading or absent.
  static void _paintProceduralVehicle(Canvas canvas, Vehicle v) {
    final pos = v.worldPos;
    final color = switch (v.type.category) {
      VehicleCategory.emergency => AppColors.coral,
      VehicleCategory.publicTransport => AppColors.sunrise,
      VehicleCategory.commercial => AppColors.sky,
      VehicleCategory.construction => const Color(0xFFFFB300),
      VehicleCategory.personal => AppColors.teal,
    };

    // Ground shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(pos.dx, pos.dy - 1), width: 24, height: 12),
      Paint()..color = const Color(0x50000000),
    );

    // Vehicle body
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(pos.dx, pos.dy - 6), width: 20, height: 10),
        const Radius.circular(3),
      ),
      Paint()..color = color,
    );

    // Windshield
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(pos.dx, pos.dy - 8), width: 12, height: 6),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xCC304050),
    );
  }

  /// Paints a pedestrian at their world position with walk stride animation.
  static void paintPedestrian({
    required Canvas canvas,
    required Pedestrian pedestrian,
    required UrbanSpriteCache cache,
    required VoidCallback onSpriteLoaded,
  }) {
    final assetPath = UrbanSpriteRegistry.pedestrianAsset(
      pedestrian.type,
      pedestrian.heading,
      pedestrian.animFrame,
    );
    cache.warmUp(assetPath, onLoaded: onSpriteLoaded);
    final sprite = cache.get(assetPath);

    if (sprite != null) {
      final w = sprite.width.toDouble();
      final h = sprite.height.toDouble();

      final dst = Rect.fromLTWH(
        pedestrian.worldPos.dx - w / 2,
        pedestrian.worldPos.dy - h * 0.90,
        w,
        h,
      );
      final src = Rect.fromLTWH(0, 0, w, h);

      final paint = Paint()
        ..isAntiAlias = true
        ..color = Color.fromRGBO(255, 255, 255, pedestrian.opacity);

      canvas.drawImageRect(sprite, src, dst, paint);
    } else {
      _paintProceduralPedestrian(canvas, pedestrian);
    }
  }

  /// Procedural fallback when pedestrian sprite is loading or absent.
  static void _paintProceduralPedestrian(Canvas canvas, Pedestrian p) {
    final pos = p.worldPos;
    final alpha = (p.opacity * 255).toInt().clamp(0, 255);

    // Ground shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(pos.dx, pos.dy - 1), width: 8, height: 4),
      Paint()..color = Color.fromARGB((alpha * 0.35).toInt(), 0, 0, 0),
    );

    final roleColor = switch (p.type) {
      PedestrianType.citizen => AppColors.teal,
      PedestrianType.officeWorker => const Color(0xFF334455),
      PedestrianType.student => AppColors.coral,
      PedestrianType.shopper => const Color(0xFFE91E63),
      PedestrianType.parkVisitor => AppColors.aqua,
      PedestrianType.constructionWorker => const Color(0xFFFF9800),
    };

    // Body
    canvas.drawRect(
      Rect.fromLTWH(pos.dx - 2.5, pos.dy - 11, 5, 6),
      Paint()..color = roleColor.withAlpha(alpha),
    );

    // Head
    canvas.drawCircle(
      Offset(pos.dx, pos.dy - 13),
      2.5,
      Paint()..color = const Color(0xFFFFD1A4).withAlpha(alpha),
    );
  }
}
