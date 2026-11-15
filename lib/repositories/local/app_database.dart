/// Drift-based local database for City Builder 2040.
///
/// No drift_dev code generation is used (see summary note in PHASE_07.md).
/// We wrap [QueryExecutor] directly with typed SQL helpers.
library;

import 'package:drift/backends.dart';
import 'package:drift/drift.dart' show OpeningDetails;
import 'package:drift_flutter/drift_flutter.dart';

// ---------------------------------------------------------------------------
// Schema version
// ---------------------------------------------------------------------------

const int _schemaVersion = 1;

// ---------------------------------------------------------------------------
// AppDatabase
// ---------------------------------------------------------------------------

/// Thin wrapper around a drift [QueryExecutor] that exposes typed SQL helpers
/// for every table. No code generation used.
class AppDatabase {
  AppDatabase._(this._executor);

  final QueryExecutor _executor;
  bool _initialised = false;

  // -------------------------------------------------------------------------
  // Factories
  // -------------------------------------------------------------------------

  /// Production database backed by a SQLite file on disk.
  ///
  /// Uses drift_flutter's [driftDatabase] which picks the correct file path
  /// for each platform (Android app-private storage, Windows %AppData%).
  static Future<AppDatabase> open() async {
    final executor = _buildProductionExecutor();
    final db = AppDatabase._(executor);
    await db.init();
    return db;
  }

  /// In-memory or custom executor database for unit tests.
  factory AppDatabase.forTesting(QueryExecutor executor) =>
      AppDatabase._(executor);

  /// In-memory database for unit tests (async open).
  static Future<AppDatabase> openInMemory(QueryExecutor executor) async {
    final db = AppDatabase._(executor);
    await db.init();
    return db;
  }

  // -------------------------------------------------------------------------
  // Lifecycle
  // -------------------------------------------------------------------------

  Future<void> init() async {
    if (_initialised) return;
    await _executor.ensureOpen(_Delegate());
    await _applySchema();
    _initialised = true;
  }

  Future<void> close() async {
    await _executor.close();
    _initialised = false;
  }

  // -------------------------------------------------------------------------
  // Schema creation / migration
  // -------------------------------------------------------------------------

  Future<void> _applySchema() async {
    // Track version in a dedicated table.
    await _run('''
CREATE TABLE IF NOT EXISTS schema_version (
  version INTEGER NOT NULL
)
''');

    final rows = await _select('SELECT version FROM schema_version LIMIT 1');
    final int stored = rows.isEmpty ? 0 : (rows.first['version'] as int? ?? 0);

    if (stored < _schemaVersion) {
      await _run('''
CREATE TABLE IF NOT EXISTS cities (
  id TEXT PRIMARY KEY NOT NULL,
  name TEXT NOT NULL,
  map_width INTEGER NOT NULL,
  map_height INTEGER NOT NULL,
  seed INTEGER NOT NULL DEFAULT 0,
  day INTEGER NOT NULL DEFAULT 1,
  population INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');

      await _run('''
CREATE TABLE IF NOT EXISTS buildings (
  id TEXT PRIMARY KEY NOT NULL,
  city_id TEXT NOT NULL,
  type_id TEXT NOT NULL,
  x INTEGER NOT NULL,
  y INTEGER NOT NULL,
  level INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');

      await _run('''
CREATE TABLE IF NOT EXISTS resource_ledgers (
  city_id TEXT PRIMARY KEY NOT NULL,
  amounts_json TEXT NOT NULL,
  updated_at TEXT NOT NULL
)
''');

      await _run('''
CREATE TABLE IF NOT EXISTS mission_progresses (
  city_id TEXT NOT NULL,
  mission_id TEXT NOT NULL,
  status TEXT NOT NULL,
  progress REAL NOT NULL DEFAULT 0.0,
  reward_claimed INTEGER NOT NULL DEFAULT 0,
  completed_at TEXT,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (city_id, mission_id)
)
''');

      await _run('''
CREATE TABLE IF NOT EXISTS player_progresses (
  player_id TEXT PRIMARY KEY NOT NULL,
  level INTEGER NOT NULL DEFAULT 1,
  experience INTEGER NOT NULL DEFAULT 0,
  unlocked_ids_json TEXT NOT NULL DEFAULT '[]',
  claimed_mission_ids_json TEXT NOT NULL DEFAULT '[]',
  completed_achievement_ids_json TEXT NOT NULL DEFAULT '[]',
  updated_at TEXT NOT NULL
)
''');

      await _run('''
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY NOT NULL,
  value TEXT NOT NULL
)
''');

      if (stored == 0) {
        await _executor.runInsert(
          'INSERT INTO schema_version (version) VALUES (?)',
          [_schemaVersion],
        );
      } else {
        await _executor.runUpdate(
          'UPDATE schema_version SET version = ?',
          [_schemaVersion],
        );
      }
    }
  }

  // -------------------------------------------------------------------------
  // Low-level helpers
  // -------------------------------------------------------------------------

  Future<void> _run(String sql) => _executor.runCustom(sql, []);

  Future<List<Map<String, Object?>>> _select(
    String sql, [
    List<Object?> args = const [],
  ]) =>
      _executor.runSelect(sql, args);

  Future<void> runInTransaction(Future<void> Function(AppDatabase tx) fn) async {
    final txExecutor = _executor.beginTransaction();
    final tx = AppDatabase._(txExecutor);
    tx._initialised = true; // schema is already applied on the parent
    try {
      await txExecutor.ensureOpen(_Delegate());
      await fn(tx);
      await txExecutor.send();
    } catch (e) {
      await txExecutor.rollback();
      rethrow;
    }
  }

  // -------------------------------------------------------------------------
  // Cities
  // -------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> listCities() => _select(
        'SELECT * FROM cities ORDER BY updated_at DESC',
      );

  Future<Map<String, Object?>?> getCity(String id) async {
    final rows = await _select('SELECT * FROM cities WHERE id = ?', [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsertCity({
    required String id,
    required String name,
    required int mapWidth,
    required int mapHeight,
    required int seed,
    required int day,
    required int population,
    required String createdAt,
    required String updatedAt,
  }) async {
    await _executor.runUpdate('''
INSERT INTO cities (id, name, map_width, map_height, seed, day, population, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  name = excluded.name,
  map_width = excluded.map_width,
  map_height = excluded.map_height,
  seed = excluded.seed,
  day = excluded.day,
  population = excluded.population,
  updated_at = excluded.updated_at
''', [id, name, mapWidth, mapHeight, seed, day, population, createdAt, updatedAt]);
  }

  Future<void> deleteCity(String id) =>
      _executor.runDelete('DELETE FROM cities WHERE id = ?', [id]);

  // -------------------------------------------------------------------------
  // Buildings
  // -------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> getBuildingsByCity(String cityId) =>
      _select('SELECT * FROM buildings WHERE city_id = ?', [cityId]);

  Future<void> upsertBuilding({
    required String id,
    required String cityId,
    required String typeId,
    required int x,
    required int y,
    required int level,
    required String createdAt,
    required String updatedAt,
  }) async {
    await _executor.runUpdate('''
INSERT INTO buildings (id, city_id, type_id, x, y, level, created_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(id) DO UPDATE SET
  type_id = excluded.type_id,
  x = excluded.x,
  y = excluded.y,
  level = excluded.level,
  updated_at = excluded.updated_at
''', [id, cityId, typeId, x, y, level, createdAt, updatedAt]);
  }

  Future<void> removeBuilding(String cityId, String buildingId) =>
      _executor.runDelete(
        'DELETE FROM buildings WHERE city_id = ? AND id = ?',
        [cityId, buildingId],
      );

  Future<void> deleteBuildingsByCity(String cityId) =>
      _executor.runDelete('DELETE FROM buildings WHERE city_id = ?', [cityId]);

  // -------------------------------------------------------------------------
  // Resource ledgers
  // -------------------------------------------------------------------------

  Future<Map<String, Object?>?> getLedger(String cityId) async {
    final rows = await _select(
      'SELECT * FROM resource_ledgers WHERE city_id = ?',
      [cityId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsertLedger({
    required String cityId,
    required String amountsJson,
    required String updatedAt,
  }) async {
    await _executor.runUpdate('''
INSERT INTO resource_ledgers (city_id, amounts_json, updated_at)
VALUES (?, ?, ?)
ON CONFLICT(city_id) DO UPDATE SET
  amounts_json = excluded.amounts_json,
  updated_at = excluded.updated_at
''', [cityId, amountsJson, updatedAt]);
  }

  Future<void> deleteLedgerByCity(String cityId) =>
      _executor.runDelete(
        'DELETE FROM resource_ledgers WHERE city_id = ?',
        [cityId],
      );

  // -------------------------------------------------------------------------
  // Mission progress
  // -------------------------------------------------------------------------

  Future<List<Map<String, Object?>>> getMissionProgress(String cityId) =>
      _select('SELECT * FROM mission_progresses WHERE city_id = ?', [cityId]);

  Future<void> upsertMissionProgress({
    required String cityId,
    required String missionId,
    required String status,
    required double progress,
    required int rewardClaimed,
    String? completedAt,
    required String updatedAt,
  }) async {
    await _executor.runUpdate('''
INSERT INTO mission_progresses (city_id, mission_id, status, progress, reward_claimed, completed_at, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(city_id, mission_id) DO UPDATE SET
  status = excluded.status,
  progress = excluded.progress,
  reward_claimed = excluded.reward_claimed,
  completed_at = excluded.completed_at,
  updated_at = excluded.updated_at
''', [cityId, missionId, status, progress, rewardClaimed, completedAt, updatedAt]);
  }

  Future<void> deleteMissionProgressByCity(String cityId) =>
      _executor.runDelete(
        'DELETE FROM mission_progresses WHERE city_id = ?',
        [cityId],
      );

  // -------------------------------------------------------------------------
  // Player progress
  // -------------------------------------------------------------------------

  Future<Map<String, Object?>?> getPlayerProgress(String playerId) async {
    final rows = await _select(
      'SELECT * FROM player_progresses WHERE player_id = ?',
      [playerId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsertPlayerProgress({
    required String playerId,
    required int level,
    required int experience,
    required String unlockedIdsJson,
    required String claimedMissionIdsJson,
    required String completedAchievementIdsJson,
    required String updatedAt,
  }) async {
    await _executor.runUpdate('''
INSERT INTO player_progresses (player_id, level, experience, unlocked_ids_json, claimed_mission_ids_json, completed_achievement_ids_json, updated_at)
VALUES (?, ?, ?, ?, ?, ?, ?)
ON CONFLICT(player_id) DO UPDATE SET
  level = excluded.level,
  experience = excluded.experience,
  unlocked_ids_json = excluded.unlocked_ids_json,
  claimed_mission_ids_json = excluded.claimed_mission_ids_json,
  completed_achievement_ids_json = excluded.completed_achievement_ids_json,
  updated_at = excluded.updated_at
''', [
      playerId,
      level,
      experience,
      unlockedIdsJson,
      claimedMissionIdsJson,
      completedAchievementIdsJson,
      updatedAt,
    ]);
  }

  // -------------------------------------------------------------------------
  // Settings (key-value)
  // -------------------------------------------------------------------------

  Future<String?> getSetting(String key) async {
    final rows = await _select(
      'SELECT value FROM app_settings WHERE key = ?',
      [key],
    );
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> putSetting(String key, String value) async {
    await _executor.runUpdate('''
INSERT INTO app_settings (key, value) VALUES (?, ?)
ON CONFLICT(key) DO UPDATE SET value = excluded.value
''', [key, value]);
  }

  Future<void> clearAllSettings() =>
      _executor.runDelete('DELETE FROM app_settings', []);
}

// ---------------------------------------------------------------------------
// Private drift delegate
// ---------------------------------------------------------------------------

class _Delegate extends QueryExecutorUser {
  @override
  int get schemaVersion => _schemaVersion;

  @override
  Future<void> beforeOpen(QueryExecutor executor, OpeningDetails details) async {}
}

// ---------------------------------------------------------------------------
// Production executor factory (import-isolated so tests don't pull in sqlite3)
// ---------------------------------------------------------------------------

QueryExecutor _buildProductionExecutor() {
  // drift_flutter's driftDatabase handles platform paths automatically.
  // Android: app-private data directory via getApplicationDocumentsDirectory()
  // Windows: %AppData%\Roaming\city_builder_2040\city_builder_2040.sqlite
  return driftDatabase(name: 'city_builder_2040');
}
