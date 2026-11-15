import 'package:city_builder_2040/models/resource_ledger.dart';

/// Persistence contract for a city's resource stockpile.
/// See `CityRepository` for the contract shared by all repositories.
abstract interface class ResourceRepository {
  Future<ResourceLedger?> getLedger(String cityId);

  Future<void> saveLedger(ResourceLedger ledger);

  /// Removes the city's ledger. Idempotent.
  Future<void> deleteByCity(String cityId);
}
