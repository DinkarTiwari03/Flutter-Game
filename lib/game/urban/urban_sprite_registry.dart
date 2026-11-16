import 'package:city_builder_2040/game/urban/compass_direction.dart';
import 'package:city_builder_2040/game/urban/pedestrian.dart';
import 'package:city_builder_2040/game/urban/vehicle.dart';

/// Registry mapping urban entities to bundled PNG sprites.
abstract final class UrbanSpriteRegistry {
  /// Asset path for a given [vehicle] heading in [direction].
  static String vehicleAsset(VehicleType type, CompassDirection direction) {
    return 'assets/vehicles/${type.assetPrefix}_${direction.code}.png';
  }

  /// Asset path for a given [pedestrian] heading in [direction] at [animFrame].
  static String pedestrianAsset(
    PedestrianType type,
    CompassDirection direction,
    int animFrame,
  ) {
    final frame = animFrame.clamp(1, 3);
    return 'assets/pedestrians/${type.assetPrefix}_${direction.code}_walk$frame.png';
  }
}
