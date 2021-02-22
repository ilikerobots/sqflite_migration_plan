library sqflite_migration_plan;

import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_migration_plan/sqflite_migration_plan.dart';

typedef OperationFn<T> = Future<T> Function(Database db);

OperationFn<void> noop = (Database db) {
  return Future.value(null);
};

class Operation<T> {
  final OperationFn<T> op;
  final MigrationErrorStrategy errorStrategy;
  Operation(this.op, {this.errorStrategy = MigrationErrorStrategy.Throw});

  Future<T> call(Database db) => op(db);
}
