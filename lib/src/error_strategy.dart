library sqflite_migration_plan;

/// Enumerates the ways in which exceptions in an [Operation] should be handled
/// during the course of upgrade or downgrade.
enum MigrationErrorStrategy {
  /// Halt and rethrow encountered exception
  Throw,

  /// Squash any encountered exceptions and proceed
  Ignore,
}
