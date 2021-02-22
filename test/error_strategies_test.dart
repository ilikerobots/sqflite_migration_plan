import 'package:logging/logging.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_migration_plan/sqflite_migration_plan.dart';
import 'package:sqflite_migration_plan/migration/sql.dart';
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

  test('onCreate forward error handling w/ throw', () async {
    MigrationPlan mc = MigrationPlan({
      1: [SqlMigration("CREATE TABLE t (i INTEGER PRIMARY KEY)")],
      2: [insertValueOp(2)],
      3: [insertValueOp(3)],
      4: [insertValueOp(4)],
      5: [insertValueOp(5)],
      6: [OperationWithErrors()],
      7: [OperationWithErrors()],
      8: [insertValueOp(8)],
      9: [insertValueOp(9)],
    });

    var path = await context.initDeleteDb('oncreate_forward_throw.db');
    try {
      await openDb(path, factory, 9, onCreate: mc);
    } catch (err) {
      expect(err is DatabaseException, true);
      expect(err is DatabaseMigrationException, true);
      expect(
          (err as DatabaseMigrationException).cause, "Forward operation error");
      expect(err.problemVersion, 6);
      expect(err.fromVersion, -1);
      expect(err.toVersion, 9);
    }
    // the first error migration is called
    expect((mc[6][0] as TestOp).forwardCalled, true);
    // but second is not
    expect((mc[7][0] as TestOp).forwardCalled, false);

    Database db = await openDb(path, factory, null);
    expect(await db.getVersion(), 0);
    expect(
        () => db.query("t", columns: ["i"]),
        throwsA(predicate(
            (e) => e is DatabaseException && e.isNoSuchTableError())));
    await db.close();
  });

  test('onCreate forward error handling w/ ignore', () async {
    MigrationPlan mc = MigrationPlan({
      1: [SqlMigration("CREATE TABLE t (i INTEGER PRIMARY KEY)")],
      2: [insertValueOp(2)],
      3: [insertValueOp(3)],
      4: [insertValueOp(4)],
      5: [insertValueOp(5)],
      6: [OperationWithErrors(errorStrategy: MigrationErrorStrategy.Ignore)],
      7: [OperationWithErrors(errorStrategy: MigrationErrorStrategy.Ignore)],
      8: [insertValueOp(8)],
      9: [insertValueOp(9)],
    });

    var path = await context.initDeleteDb('oncreate_forward_ignore.db');
    Database db = await openDb(path, factory, 9, onCreate: mc);
    expect(await db.getVersion(), 9);
    expect((await db.query("t", columns: ["i"])).length, 6);
    // both error migrations were called
    expect((mc[6][0] as TestOp).forwardCalled, true);
    expect((mc[7][0] as TestOp).forwardCalled, true);

    await db.close();
  });

  test('onUpgrade forward error handling w/ throw', () async {
    MigrationPlan mc = MigrationPlan({
      1: [SqlMigration("CREATE TABLE t (i INTEGER PRIMARY KEY)")],
      2: [insertValueOp(2)],
      3: [insertValueOp(3)],
      4: [insertValueOp(4)],
      5: [insertValueOp(5)],
      6: [OperationWithErrors()],
      7: [OperationWithErrors()],
      8: [insertValueOp(8)],
      9: [insertValueOp(9)],
    });
    var path = await context.initDeleteDb('onupgrade_forward_throw.db');

    Database db = await openDb(path, factory, null);
    await db.close();

    try {
      await openDb(path, factory, 8, onUpgrade: mc);
    } catch (err) {
      expect(err is DatabaseMigrationException, true);
      expect(
          (err as DatabaseMigrationException).cause, "Forward operation error");
      expect(err.problemVersion, 6);
      expect(err.fromVersion, 0);
      expect(err.toVersion, 8);
    }
    //first error migration was called
    expect((mc[6][0] as TestOp).forwardCalled, true);
    // but second is not
    expect((mc[7][0] as TestOp).forwardCalled, false);

    db = await openDb(path, factory, null);
    expect(await db.getVersion(), 0);
    expect(
        () => db.query("t", columns: ["i"]),
        throwsA(predicate(
            (e) => e is DatabaseException && e.isNoSuchTableError())));
    await db.close();
  });

  test('onUpgrade forward error handling w/ ignore', () async {
    MigrationPlan mc = MigrationPlan({
      1: [SqlMigration("CREATE TABLE t (i INTEGER PRIMARY KEY)")],
      2: [insertValueOp(2)],
      3: [insertValueOp(3)],
      4: [insertValueOp(4)],
      5: [insertValueOp(5)],
      6: [OperationWithErrors(errorStrategy: MigrationErrorStrategy.Ignore)],
      7: [OperationWithErrors(errorStrategy: MigrationErrorStrategy.Ignore)],
      8: [insertValueOp(8)],
      9: [insertValueOp(9)],
    });

    var path = await context.initDeleteDb('onupgrade_forward_ignore.db');
    Database db = await openDb(path, factory, null);
    await db.close();

    db = await openDb(path, factory, 9, onUpgrade: mc);
    expect(await db.getVersion(), 9);
    expect((await db.query("t", columns: ["i"])).length, 6);
    // both error migrations were called
    expect((mc[6][0] as TestOp).forwardCalled, true);
    expect((mc[7][0] as TestOp).forwardCalled, true);

    await db.close();
  });

  test('onDowngrade reverse error handling w/ throw', () async {
    MigrationPlan mc = MigrationPlan({
      1: [
        SqlMigration("CREATE TABLE t (i INTEGER PRIMARY KEY)",
            reverseSql: "DROP TABLE t")
      ],
      2: [insertValueOp(2)],
      3: [insertValueOp(3)],
      4: [insertValueOp(4)],
      5: [insertValueOp(5)],
      6: [OperationWithReverseError()],
      7: [OperationWithReverseError()],
      8: [insertValueOp(8)],
      9: [insertValueOp(9)],
    });
    var path = await context.initDeleteDb('ondowngrade_reverse_throw.db');

    Database db = await openDb(path, factory, 9, onCreate: mc);
    await db.close();

    try {
      await openDb(path, factory, 1, onDowngrade: mc);
    } catch (err) {
      expect(err is DatabaseMigrationException, true);
      expect(
          (err as DatabaseMigrationException).cause, "Reverse operation error");
      expect(err.problemVersion, 7);
      expect(err.fromVersion, 9);
      expect(err.toVersion, 1);
    }
    //second reverse error migration was called
    expect((mc[7][0] as TestOp).reverseCalled, true);
    // but first is not
    expect((mc[6][0] as TestOp).reverseCalled, false);

    db = await openDb(path, factory, null);
    expect(await db.getVersion(), 9);
    expect((await db.query("t", columns: ["i"])).length, 6);
    await db.close();
  });

  test('onDowngrade reverse error handling w/ ignore', () async {
    MigrationPlan mc = MigrationPlan({
      1: [
        SqlMigration("CREATE TABLE t (i INTEGER PRIMARY KEY)",
            reverseSql: "DROP TABLE t")
      ],
      2: [insertValueOp(2)],
      3: [insertValueOp(3)],
      4: [insertValueOp(4)],
      5: [insertValueOp(5)],
      6: [
        OperationWithReverseError(errorStrategy: MigrationErrorStrategy.Ignore)
      ],
      7: [
        OperationWithReverseError(errorStrategy: MigrationErrorStrategy.Ignore)
      ],
      8: [insertValueOp(8)],
      9: [insertValueOp(9)],
    });
    var path = await context.initDeleteDb('ondowngrade_reverse_ignore.db');

    Database db = await openDb(path, factory, 9, onCreate: mc);
    await db.close();

    db = await openDb(path, factory, 1, onDowngrade: mc);
    //second reverse error migration was called
    expect((mc[7][0] as TestOp).reverseCalled, true);
    // but first is not
    expect((mc[6][0] as TestOp).reverseCalled, true);

    expect(await db.getVersion(), 1);
    expect((await db.query("t", columns: ["i"])).length, 0);
    await db.close();
  });

  test('forward ignore and reverse throw error strategies', () async {
    MigrationPlan mc = MigrationPlan({
      1: [
        SqlMigration("CREATE TABLE t (i INTEGER PRIMARY KEY)",
            reverseSql: "DROP TABLE t")
      ],
      2: [insertValueOp(2)],
      3: [insertValueOp(3)],
      4: [insertValueOp(4)],
      5: [insertValueOp(5)],
      6: [
        OperationWithErrors(
            errorStrategy: MigrationErrorStrategy.Ignore,
            reverseErrorStrategy: MigrationErrorStrategy.Throw)
      ],
      7: [insertValueOp(7)],
      8: [insertValueOp(8)],
    });
    var path = await context.initDeleteDb('forward_ignore_reverse_throw.db');

    Database db = await openDb(path, factory, 8, onCreate: mc, onDowngrade: mc);
    await db.close();
    try {
      await openDb(path, factory, 1,
          onCreate: mc, onUpgrade: mc, onDowngrade: mc);
    } catch (err) {
      expect(err is DatabaseException, true);
      expect(err is DatabaseMigrationException, true);
      expect(
          (err as DatabaseMigrationException).cause, "Reverse operation error");
      expect(err.problemVersion, 6);
      expect(err.fromVersion, 8);
      expect(err.toVersion, 1);
    }

    db = await openDb(path, factory, null);
    expect(await db.getVersion(), 8);
    await db.close();
  });
  test('forward throw and reverse ignore error strategies', () async {
    MigrationPlan mc = MigrationPlan({
      1: [
        SqlMigration("CREATE TABLE t (i INTEGER PRIMARY KEY)",
            reverseSql: "DROP TABLE t")
      ],
      2: [insertValueOp(2)],
      3: [insertValueOp(3)],
      4: [insertValueOp(4)],
      5: [insertValueOp(5)],
      6: [
        OperationWithErrors(
            errorStrategy: MigrationErrorStrategy.Throw,
            reverseErrorStrategy: MigrationErrorStrategy.Ignore)
      ],
      7: [insertValueOp(7)],
      8: [insertValueOp(8)],
    });
    var path = await context.initDeleteDb('forward_throw_reverse_ignore.db');

    Database db = await openDb(path, factory, 9,
        onCreate: MigrationPlan({
          5: [
            SqlMigration("CREATE TABLE t (i INTEGER PRIMARY KEY)",
                reverseSql: "DROP TABLE t")
          ]
        }));
    await db.close();

    db = await openDb(path, factory, 1,
        onCreate: mc, onUpgrade: mc, onDowngrade: mc);
    await db.close();

    try {
      await openDb(path, factory, 8,
          onCreate: mc, onUpgrade: mc, onDowngrade: mc);
    } catch (err) {
      expect(err is DatabaseMigrationException, true);
      expect(
          (err as DatabaseMigrationException).cause, "Forward operation error");
      expect(err.problemVersion, 6);
      expect(err.fromVersion, 1);
      expect(err.toVersion, 8);
    }

    db = await openDb(path, factory, null);
    expect(await db.getVersion(), 1);
    await db.close();
  });
}
