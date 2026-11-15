import 'dart:convert';

import 'package:city_builder_2040/core/utils/app_exception.dart';
import 'package:city_builder_2040/models/resource_ledger.dart';
import 'package:city_builder_2040/repositories/local/app_database.dart';
import 'package:city_builder_2040/repositories/resource_repository.dart';

class LocalResourceRepository implements ResourceRepository {
  LocalResourceRepository(this._db);
  final AppDatabase _db;

  @override
  Future<ResourceLedger?> getLedger(String cityId) async {
    try {
      final row = await _db.getLedger(cityId);
      if (row == null) return null;
      return _fromRow(row);
    } catch (e, s) {
      throw RepositoryException('Failed to get ledger for city $cityId.', cause: e, stackTrace: s);
    }
  }

  @override
  Future<void> saveLedger(ResourceLedger ledger) async {
    try {
      final amountsJson = jsonEncode(ledger.amounts);
      await _db.upsertLedger(
        cityId: ledger.cityId,
        amountsJson: amountsJson,
        updatedAt: ledger.updatedAt.toUtc().toIso8601String(),
      );
    } catch (e, s) {
      throw RepositoryException('Failed to save ledger for city ${ledger.cityId}.', cause: e, stackTrace: s);
    }
  }

  @override
  Future<void> deleteByCity(String cityId) async {
    try {
      await _db.deleteLedgerByCity(cityId);
    } catch (e, s) {
      throw RepositoryException('Failed to delete ledger for city $cityId.', cause: e, stackTrace: s);
    }
  }

  static ResourceLedger _fromRow(Map<String, Object?> row) {
    final rawJson = row['amounts_json'] as String;
    final decoded = jsonDecode(rawJson) as Map;
    final amounts = decoded.map(
      (k, v) => MapEntry(k as String, (v as num).toDouble()),
    );
    return ResourceLedger(
      cityId: row['city_id'] as String,
      amounts: amounts,
      updatedAt: DateTime.parse(row['updated_at'] as String),
    );
  }
}
