library sqflite_migration_plan;

import 'package:sqflite/sqflite.dart';

/// An error encountered while calling in the course of an upgrade or downgrade.
///
/// Generally will be caused by an error thrown in the course of executing
/// an [Operation]'s forward or reverse operation.  As this exception implements
/// [DatabaseException], if the underlying [cause] was a DatabaseException, then
/// this exception itself can be used directly to query for common database
/// errors, e.g.
/// ```dart
/// try {
///   // open database and migrate (if needed)
/// } on DatabaseMigrationException catch (err) {
///     if (err.isOpenFailedError()) {
///       // handle
///     } else if (err.isSyntaxError()) {
///       // handle
///     } else {
///       // handle
///     }
/// }
/// ```
///
/// If the underlying cause is other than a [DatabaseException], which can
/// often be the cause with custom [Operation]s, the [cause] can be directly
/// inspected as needed to properly handle the error.
class DatabaseMigrationException implements DatabaseException {
  /// Starting version of the migration being performed when the error occurred
  int fromVersion;

  /// Target end version of the migration being performed when the error occurred
  int toVersion;

  /// The version whose migration(s) were being executed when the error occurred
  int problemVersion;

  /// The original error thrown
  dynamic cause;

  final String _message;

  DatabaseMigrationException(
    this.fromVersion,
    this.toVersion,
    this.problemVersion,
    this.cause,
  ) : this._message =
            "Migration from version $fromVersion to $toVersion failed at version $problemVersion due to $cause";

  @override
  int? getResultCode() => cause is DatabaseException
      ? (cause as DatabaseException).getResultCode()
      : null;

  @override
  bool isDatabaseClosedError() => cause is DatabaseException
      ? (cause as DatabaseException).isDatabaseClosedError()
      : false;

  @override
  bool isDuplicateColumnError([String? column]) => cause is DatabaseException
      ? (cause as DatabaseException).isDuplicateColumnError(column)
      : false;

  @override
  bool isNoSuchTableError([String? table]) => cause is DatabaseException
      ? (cause as DatabaseException).isNoSuchTableError(table)
      : false;

  @override
  bool isNotNullConstraintError([String? field]) => cause is DatabaseException
      ? (cause as DatabaseException).isNotNullConstraintError(field)
      : false;

  @override
  bool isOpenFailedError() => cause is DatabaseException
      ? (cause as DatabaseException).isOpenFailedError()
      : false;

  @override
  bool isReadOnlyError() => cause is DatabaseException
      ? (cause as DatabaseException).isReadOnlyError()
      : false;

  @override
  bool isSyntaxError() => cause is DatabaseException
      ? (cause as DatabaseException).isSyntaxError()
      : false;

  @override
  bool isUniqueConstraintError([String? field]) => cause is DatabaseException
      ? (cause as DatabaseException).isUniqueConstraintError(field)
      : false;

  @override
  String toString() => 'DatabaseMigrationException($_message)';

  @override
  Object? get result => null;
}
