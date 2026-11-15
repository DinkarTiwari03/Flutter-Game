import 'package:city_builder_2040/models/resource_ledger.dart';
import 'package:city_builder_2040/repositories/resource_repository.dart';

/// Non-persistent [ResourceRepository].
class MemoryResourceRepository implements ResourceRepository {
  final Map<String, ResourceLedger> _ledgers = {};

  @override
  Future<ResourceLedger?> getLedger(String cityId) async => _ledgers[cityId];

  @override
  Future<void> saveLedger(ResourceLedger ledger) async =>
      _ledgers[ledger.cityId] = ledger;

  @override
  Future<void> deleteByCity(String cityId) async => _ledgers.remove(cityId);
}
