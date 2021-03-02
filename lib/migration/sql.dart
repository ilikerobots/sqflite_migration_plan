/// Library of specific-case migrations implementing the base [Migration].
library sqlflite_migration_plan_migrations;

import 'package:sqflite_migration_plan/sqflite_migration_plan.dart';

/// Describes a migration using an SQL statement.
///
/// [SqlMigration] will execute the given migration sql via sqflite
/// Database.execute() method.
class SqlMigration extends Migration {
  /// Construct a migration that will execute [sql] during upgrade (and
  /// [reverseSql] during downgrade, if provided).
  SqlMigration(
    String sql, {
    String? reverseSql,
    MigrationErrorStrategy? errorStrategy,
    MigrationErrorStrategy? reverseErrorStrategy,
  }) : super(
            Operation<void>((db) async => db.execute(sql),
                errorStrategy: errorStrategy ?? MigrationErrorStrategy.Throw),
            reverse: Operation<void>(
                reverseSql != null
                    ? (db) async => db.execute(reverseSql)
                    : noop,
                errorStrategy: reverseErrorStrategy ??
                    errorStrategy ??
                    MigrationErrorStrategy.Throw));
}
