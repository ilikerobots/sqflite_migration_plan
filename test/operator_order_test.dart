import 'package:logging/logging.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_migration_plan/migration/sql.dart';
import 'package:sqflite_migration_plan/sqflite_migration_plan.dart';
import 'package:test/test.dart';

import 'src/logging.dart';
import 'src/sqflite_test_context.dart';
import 'src/oepration_fixtures.dart';
import 'src/util.dart';

export 'package:sqflite_common/sqflite_dev.dart';

class SqfliteFfiTestContext extends SqfliteLocalTestContext {
  SqfliteFfiTestContext() : super(databaseFactoryFfi);
}

void main() {
  var ffiTestContext = SqfliteFfiTestContext();
  sqfliteFfiInit();

  run(ffiTestContext);
}

void run(SqfliteTestContext context) {
  Logger.root.level = LOG_LEVEL;
  Logger.root.onRecord.listen(LOGGER_METHOD);
  var factory = context.databaseFactory;

  test('upgrade operation order', () async {
    MigrationPlan mc = MigrationPlan({
      1: [
        SqlMigration("CREATE TABLE t (i INTEGER PRIMARY KEY)",
            reverseSql: "DROP TABLE t")
      ],
      2: [TestOp(), TestOp(), TestOp()],
      3: [TestOp(), OperationWithErrors(), TestOp()],
      4: [TestOp(), TestOp(), TestOp()],
    });
    var path = await context.initDeleteDb('up_ops.db');

    try {
      await openDb(path, factory, 10,
          onCreate: mc, onUpgrade: mc, onDowngrade: mc);
    } catch (err) {
      expect(err is DatabaseMigrationException, true);
    }

    expect((mc[2][0] as TestOp).forwardCalled, true);
    expect((mc[2][1] as TestOp).forwardCalled, true);
    expect((mc[2][2] as TestOp).forwardCalled, true);
    expect((mc[3][0] as TestOp).forwardCalled, true);
    expect((mc[3][1] as TestOp).forwardCalled, true);
    expect((mc[3][2] as TestOp).forwardCalled, false);
    expect((mc[4][0] as TestOp).forwardCalled, false);
    expect((mc[4][1] as TestOp).forwardCalled, false);
    expect((mc[4][2] as TestOp).forwardCalled, false);
  });

  test('downgrade operation order', () async {
    MigrationPlan mc = MigrationPlan({
      1: [
        SqlMigration("CREATE TABLE t (i INTEGER PRIMARY KEY)",
            reverseSql: "DROP TABLE t")
      ],
      2: [TestOp(), TestOp(), TestOp()],
      3: [TestOp(), OperationWithReverseError(), TestOp()],
      4: [TestOp(), TestOp(), TestOp()],
    });
    var path = await context.initDeleteDb('down_ops.db');

    Database db = await openDb(path, factory, 10,
        onCreate: mc, onUpgrade: mc, onDowngrade: mc);
    await db.close();
    try {
      await openDb(path, factory, 1,
          onCreate: mc, onUpgrade: mc, onDowngrade: mc);
    } catch (err) {
      expect(err is DatabaseMigrationException, true);
    }

    expect((mc[2][0] as TestOp).reverseCalled, false);
    expect((mc[2][1] as TestOp).reverseCalled, false);
    expect((mc[2][2] as TestOp).reverseCalled, false);
    expect((mc[3][0] as TestOp).reverseCalled, false);
    expect((mc[3][1] as TestOp).reverseCalled, true);
    expect((mc[3][2] as TestOp).reverseCalled, true);
    expect((mc[4][0] as TestOp).reverseCalled, true);
    expect((mc[4][1] as TestOp).reverseCalled, true);
    expect((mc[4][2] as TestOp).reverseCalled, true);
  });
}
