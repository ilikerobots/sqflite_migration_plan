import 'package:sqflite_migration_plan/migration/sql.dart';
import 'package:sqflite_migration_plan/sqflite_migration_plan.dart';

SqlMigration insertValueOp(int i) => SqlMigration("INSERT INTO t VALUES ($i)",
    reverseSql: "DELETE FROM t WHERE i=$i");

class TestOp implements Migration {
  bool forwardCalled = false;
  bool reverseCalled = false;
  final MigrationErrorStrategy errorStrategy;
  final MigrationErrorStrategy? reverseErrorStrategy;

  TestOp({errorStrategy, this.reverseErrorStrategy})
      : this.errorStrategy = errorStrategy ?? MigrationErrorStrategy.Throw;

  @override
  get forward => Operation((db) {
        forwardCalled = true;
        return Future.value(null);
      }, errorStrategy: errorStrategy);

  @override
  get reverse => Operation((db) {
        reverseCalled = true;
        return Future.value(null);
      }, errorStrategy: reverseErrorStrategy ?? errorStrategy);
}

class OperationWithErrors extends TestOp {
  OperationWithErrors({errorStrategy, reverseErrorStrategy})
      : super(
            errorStrategy: errorStrategy,
            reverseErrorStrategy: reverseErrorStrategy);

  @override
  get forward => Operation((db) {
        super.forward(db);
        throw ("Forward operation error");
      }, errorStrategy: errorStrategy);

  @override
  get reverse => Operation((db) {
        super.reverse(db);
        throw ("Reverse operation error");
      }, errorStrategy: reverseErrorStrategy ?? errorStrategy);
}

class OperationWithReverseError extends TestOp {
  OperationWithReverseError({errorStrategy, reverseErrorStrategy})
      : super(
            errorStrategy: errorStrategy,
            reverseErrorStrategy: reverseErrorStrategy);

  @override
  get forward => super.forward;

  @override
  get reverse => Operation((db) {
        super.reverse(db);
        throw ("Reverse operation error");
      }, errorStrategy: reverseErrorStrategy ?? errorStrategy);
}
