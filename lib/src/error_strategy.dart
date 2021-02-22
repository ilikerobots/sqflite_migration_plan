library sqflite_migration_plan;

enum MigrationErrorStrategy {
  Throw, // Immediately rethrow encountered exception
  Ignore, // Squash any encountered exceptions and proceed
}
