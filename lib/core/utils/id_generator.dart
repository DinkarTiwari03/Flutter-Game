import 'dart:math';

/// Generates unique string ids on the client.
///
/// Ids are created locally (not by a database) so records can be created
/// offline and later synced to a cloud backend without id collisions.
class IdGenerator {
  IdGenerator([Random? random]) : _random = random ?? Random.secure();

  final Random _random;

  String next() {
    final time = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final noise =
        List.generate(
          6,
          (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
    return '$time-$noise';
  }
}
