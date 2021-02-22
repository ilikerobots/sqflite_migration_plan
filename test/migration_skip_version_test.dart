import 'package:logging/logging.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_migration_plan/migration/sql.dart';
import 'package:sqflite_migration_plan/sqflite_migration_plan.dart';
import 'package:test/test.dart';

import 'src/logging.dart';
import 'src/oepration_fixtures.dart';
import 'src/sqflite_test_context.dart';
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

  test('skipping versions', () async {
    MigrationPlan mc = MigrationPlan({
      1: [
        SqlMigration("CREATE TABLE t (i INTEGER PRIMARY KEY)",
            reverseSql: "DROP TABLE t")
      ],
      2: [insertValueOp(2)],
      3: [insertValueOp(3)],
      4: [insertValueOp(4)],
      5: [insertValueOp(5)],
      6: [insertValueOp(6)],
      7: [insertValueOp(7)],
      8: [insertValueOp(8)],
    });
    var path = await context.initDeleteDb('skip_versions.db');

    Database db = await openDb(path, factory, 15,
        onCreate: MigrationPlan({
          5: [
            SqlMigration("CREATE TABLE t (i INTEGER PRIMARY KEY)",
                reverseSql: "DROP TABLE t")
          ]
        }));
    expect(await db.getVersion(), 15);
    await db.close();

    db = await openDb(path, factory, 1,
        onCreate: mc, onUpgrade: mc, onDowngrade: mc);
    expect(await db.getVersion(), 1);
    await db.close();

    db = await openDb(path, factory, 12,
        onCreate: mc, onUpgrade: mc, onDowngrade: mc);

    // db = await openDb(path, factory, null);
    expect(await db.getVersion(), 12);
    await db.close();
  });
}
