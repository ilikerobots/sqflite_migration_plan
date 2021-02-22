library sqflite_migration_plan;

import 'package:sqflite/sqflite.dart';

class MigrationOperationException {
  int problemVersion;
  dynamic cause;

  MigrationOperationException(
    this.problemVersion,
    this.cause,
  );
}

class DatabaseMigrationException extends DatabaseException {
  int fromVersion;
  int toVersion;
  int problemVersion;
  dynamic cause;

  DatabaseMigrationException(
    this.fromVersion,
    this.toVersion,
    this.problemVersion,
    this.cause,
  ) : super("Migration from version $fromVersion to $toVersion failed at version $problemVersion due to $cause");

  @override
  int? getResultCode() => cause is DatabaseException
      ? (cause as DatabaseException).getResultCode()
      : null;
}
