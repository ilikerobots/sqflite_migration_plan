import 'package:sqflite/sqflite.dart';
import 'package:sqflite_migration_plan/sqflite_migration_plan.dart';

class CaptureResultOperation<T> extends Operation<T> {
  Future<T>? result;

  CaptureResultOperation(op, {errorStrategy = MigrationErrorStrategy.Throw})
      : super(op, errorStrategy: errorStrategy);

  Future<T> call(Database db) {
    Future<T> thisResult = super.call(db);
    result = thisResult;
    return thisResult;
  }
}

class SetColumnDefaultOperation extends CaptureResultOperation<int> {
  SetColumnDefaultOperation(String table, String col, String value)
      : super((Database db) =>
            db.update(table, {col: value}, where: '$col IS NULL'));
}
