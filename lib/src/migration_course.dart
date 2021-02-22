library sqflite_migration_plan;

import 'dart:async';

import 'package:logging/logging.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_migration_plan/sqflite_migration_plan.dart';

class MigrationCourse {
  final log = Logger('SqlfliteMigrator');
  final List<int> _versions;
  final Map<int, List<Operation>> _opsByVersion;

  MigrationCourse(this._versions, this._opsByVersion);

  Future<void> execute(Database db) async {
    for (int version in _versions) {
      List<Operation> ops = _opsByVersion[version] ?? const [];
      log.finer(
          "Executing migration course with ${ops.length} operation(s) for version $version");
      try {
        await _execOperationsForVersion(ops, db);
      } catch (err) {
        log.fine("Error during migration course at ver $version: $err");
        throw MigrationOperationException(version, err);
      }
    }
    return Future.value(null);
  }

  Future<void> _execOperationsForVersion(
      List<Operation> operations, Database db) async {
    int i = 0;
    for (Operation operation in operations) {
      try {
        log.finest("Executing migration operation $i for this version");
        await operation(db);
        i++;
      } catch (err) {
        if (operation.errorStrategy == MigrationErrorStrategy.Throw) {
          log.fine(
              "Aborting migration due to error strategy ${operation.errorStrategy}");
          rethrow;
        } else {
          log.finer(
              "Ignoring migration due to error strategy ${operation.errorStrategy}");
        }
      }
    }
    return Future.value(null);
  }
}
