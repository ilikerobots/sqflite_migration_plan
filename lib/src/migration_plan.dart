library sqflite_migration_plan;

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_migration_plan/sqflite_migration_plan.dart';

import 'exception.dart';
import 'migration_course.dart';

class MigrationPlan {
  final log = Logger('SqlfliteMigrator');
  final Map<int, List<Migration>> _migrationsByVersion;

  MigrationPlan(this._migrationsByVersion);

  List<Migration> operator [](int v) => _migrationsByVersion[v] ?? [];
  // operator []=(int v, Operation op) => migrations.add(m);

  Future<void> call(Database db, int fromVersion, [int toVersion = -1]) async {
    // If called from onCreate, toVersion is missing; fromVersion is actually toVersion
    final int trueFromVer = toVersion >= 0 ? fromVersion : -1;
    final int trueToVer = toVersion >= 0 ? toVersion : fromVersion;
    MigrationCourse course = _courseForVersions(trueFromVer, trueToVer);
    log.fine("Established db migration course from $trueFromVer to $trueToVer");
    try {
      return await course.execute(db);
    } catch (err) {
      int eVer = (err is MigrationOperationException) ? err.problemVersion : -1;
      dynamic eCause = (err is MigrationOperationException) ? err.cause : err;
      log.info("Caught exception at version $eVer during migration: $eCause");

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
