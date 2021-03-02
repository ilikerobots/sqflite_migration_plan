library sqflite_migration_plan;

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_migration_plan/sqflite_migration_plan.dart';

import 'exception.dart';
import 'migration_course.dart';
import 'migration_operation_exception.dart';

/// A roadmap of operations which cumulatively describe how a database is
/// migrated (upgraded or downgraded) from any version to any version.
///
/// The MigrationPlan is conceptually a map associating each database version
/// with a list of [Migration]s.  These operations would commonly include such
/// things as creating tables, populating initial data, and adding columns.
class MigrationPlan {
  final _log = Logger('SqlfliteMigrator');
  final Map<int, List<Migration>> _migrationsByVersion;

  /// Build a MigrationPlan from a map associating database versions to the
  /// list of [Migration]s that cumulatively upgrade to (or downgrade from) that
  /// version.
  ///
  /// ```dart
  /// MigrationPlan myMigrationPlan = MigrationPlan({
  ///
  ///   2: [ //Migration for v2: create a table using SQL Operation
  ///     SqlMigration('''CREATE TABLE $_table ( $_my_columns )''')
  ///                    reverseSql: 'DROP TABLE $_table')// Reverse drops the table
  ///   ],
  ///
  ///   3: [  //Migration for v3: add initial records using custom function
  ///     Migration(Operation((db) async {
  ///       _insertRecord(Entity(null, "Mordecai", "Pitcher"), db);
  ///       _insertRecord(Entity(null, "Tommy", "Pitcher"), db);
  ///       _insertRecord(Entity(null, "Max", "Center Field"), db);
  ///     }), reverse: Operation((db) async => db.execute('DELETE FROM $_table')))
  ///   ],
  ///
  ///   4: [// Two migration for v4: add a column, set initial values
  ///     // a custom Migration defines desired behavior of adding/removing col
  ///     AddColumnMigration(_table, _columnHome['name']!, _columnHome['def']!,
  ///         [_columnId, _columnName, _columnDesc]),
  ///     Migration.fromOperationFunctions((db) async => db.execute(
  ///         'UPDATE $_table SET ${_columnHome['name']} = \'Terre Haute\'')),
  ///     // Omit the reverse; no action on downgrade of this operation
  ///   ],
  /// });
  /// ```
  MigrationPlan(this._migrationsByVersion);

  List<Migration> operator [](int v) => _migrationsByVersion[v] ?? [];
  // operator []=(int v, Operation op) => migrations.add(m);

  /// Execute this migration plan.
  ///
  /// Migrates the database [db] to the specified version. The signature of this
  /// method is designed to be compatible with the sqflite openDatabase()
  /// onCreate, onUpgrade, and onDowngrade parameters, and is thus somewhat
  /// oddly arranged.
  ///
  /// If [toVersion] is omitted, then the database is assumed to migrate from
  /// version 0 to [version]. Otherwise, the database is assumed to migrate from
  /// [version] to [toVersion].
  ///
  /// When an error is thrown during execution of an [Operation], it will be
  /// handled as specified by that Operation's [MigrationErrorStrategy].
  ///
  /// If for some reason the database should be migrated outside of the context
  /// of openDatabase, it may be done so "manually", e.g.
  /// ```dart
  /// MigrationPlan myMigrationPlan = MigrationPlan({
  ///   // your migrations
  /// });
  /// myMigrationPlan(db, 2, 5);  // manually run a migration from version 2 to 5
  /// ```
  Future<void> call(Database db, int version, [int toVersion = -1]) async {
    // If called from onCreate, toVersion is missing; fromVersion is actually toVersion
    final int trueFromVer = toVersion >= 0 ? version : -1;
    final int trueToVer = toVersion >= 0 ? toVersion : version;
    MigrationCourse course = _courseForVersions(trueFromVer, trueToVer);
    _log.fine(
        "Established db migration course from $trueFromVer to $trueToVer");
    try {
      return await course.execute(db);
    } catch (err) {
      int eVer = (err is MigrationOperationException) ? err.problemVersion : -1;
      dynamic eCause = (err is MigrationOperationException) ? err.cause : err;
      _log.info("Caught exception at version $eVer during migration: $eCause");

      // if exception, the sqlflite onCreate, onUpgrade, onDowngrade handlers
      // will do the equivalent of a rollback of entire the migration course
      throw DatabaseMigrationException(trueFromVer, trueToVer, eVer, eCause);
    }
  }

  // Build a specific course of operations for a migration between two versions
  MigrationCourse _courseForVersions(int fromVersion, int toVersion) {
    final bool isUpgrade = _isUpgrade(fromVersion, toVersion);
    final List<int> versions = _versionsToMigrate(fromVersion, toVersion);
    final ops = Map<int, List<Operation>>.unmodifiable(Map.fromIterable(
        _migrationsByVersion.keys.where((k) => versions.contains(k)),
        value: (k) => (isUpgrade ? this[k] : this[k].reversed)
            .map((Migration m) => isUpgrade ? m.forward : m.reverse)
            .toList()));
    return MigrationCourse(versions, ops);
  }

  bool _isUpgrade(int fromVersion, int toVersion) => toVersion > fromVersion;

  List<int> _versionsToMigrate(int fromVersion, int toVersion) {
    if (fromVersion == toVersion) {
      return [];
    } else if (fromVersion < toVersion) {
      return (_migrationsByVersion.keys
          .where((v) => v > fromVersion && v <= toVersion)
          .toList()
            ..sort((a, b) => a.compareTo(b)));
    } else {
      return (_migrationsByVersion.keys
          .where((v) => v <= fromVersion && v > toVersion)
          .toList()
            ..sort((a, b) => b.compareTo(a)));
    }
  }
}
