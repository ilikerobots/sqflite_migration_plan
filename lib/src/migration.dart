library sqflite_migration_plan;

import 'package:sqflite_migration_plan/sqflite_migration_plan.dart';

class Migration {
  final Operation forward;
  final Operation reverse;

  Migration(this.forward, {reverse})
      : this.reverse = reverse ?? Operation(noop);

  Migration.fromOperationFunctions(forwardOp,
      {reverseOp,
      errorStrategy = MigrationErrorStrategy.Throw,
      reverseErrorStrategy})
      : this.forward = Operation(forwardOp, errorStrategy: errorStrategy),
        this.reverse = Operation(reverseOp ?? noop,
            errorStrategy: reverseErrorStrategy ?? errorStrategy ?? noop);
}
