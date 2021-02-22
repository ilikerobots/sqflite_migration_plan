library sqlflite_migration_plan_migrations;

import 'package:sqflite_migration_plan/sqflite_migration_plan.dart';

class SqlMigration extends Migration {
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
