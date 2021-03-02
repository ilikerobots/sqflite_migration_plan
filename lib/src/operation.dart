library sqflite_migration_plan;

import 'dart:async';

import 'package:sqflite/sqflite.dart';
import 'package:sqflite_migration_plan/sqflite_migration_plan.dart';

/// A function accepting a [Database] and returning a Future; an [Operation]
/// is built from such functions.
typedef OperationFn<T> = Future<T> Function(Database db);

/// A no-operation, simply immediately returning a Future to null.
OperationFn<void> noop = (Database db) {
  return Future.value(null);
};

/// An operation [op] along with its associated [errorStrategy].
///
/// Normally, this would represent one-half of [Migration], i.e. either the
/// forward (upgrade) operation or the reverse (downgrade) operation.
class Operation<T> {
  final OperationFn<T> op;
  final MigrationErrorStrategy errorStrategy;

  /// Construct an operation from its OperationFn [fn] and [errorStrategy].
  Operation(this.op, {this.errorStrategy = MigrationErrorStrategy.Throw});

  /// Execute the operation ([op]) against the database [db].
  Future<T> call(Database db) => op(db);
}
