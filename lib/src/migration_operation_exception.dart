/// An error encountered while calling an [Operation]'s forward or reverse
/// functions.
class MigrationOperationException {
  /// The version number for which the Operation in error was associated.
  int problemVersion;

  /// The original error thrown by the Operation.
  dynamic cause;

  MigrationOperationException(
    this.problemVersion,
    this.cause,
  );
}
