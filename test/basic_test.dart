import 'dart:io';

import 'package:logging/logging.dart';
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common/utils/utils.dart' as utils;
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

/// Verify a condition in a test.
bool verify(bool condition, [String? message]) {
  message ??= 'verify failed';
  expect(condition, true, reason: message);
  return condition;
}

/// Run tests.
void run(SqfliteTestContext context) {
  Logger.root.level = LOG_LEVEL;
  Logger.root.onRecord.listen(LOGGER_METHOD);

  var factory = context.databaseFactory;

  test('Open no version onCreate', () async {
    // should fail
    var path = await context.initDeleteDb('open_no_version_on_create.db');
    verify(!(File(path).existsSync()));
    Database? db;
    try {
      db = await factory.openDatabase(path,
          options: OpenDatabaseOptions(onCreate: (Database db, int version) {
        // never called
        verify(false);
      }));
      verify(false);
    } on ArgumentError catch (_) {}
    verify(!File(path).existsSync());
    expect(db, null);
  });

  test('Open onCreate migrates to version 1', () async {
    // await utils.devSetDebugModeOn(true);
    TestOp opVer1 = TestOp();
    MigrationPlan mc = new MigrationPlan({
      1: [opVer1]
    });

    // Forward creates the table
    var path = await context.initDeleteDb('open_oncreate_ver_1.db');
    var db = await factory.openDatabase(path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: mc,
        ));
    expect(opVer1.forwardCalled, true);
    expect(opVer1.reverseCalled, false);
    await db.close();
  });

  test('onCreate migrates to version N', () async {
    int maxVersion = 7;
    int toVersion = 5;
    // await utils.devSetDebugModeOn(true);
    List<TestOp> ops =
        Iterable<int>.generate(maxVersion).map((i) => TestOp()).toList();
    MigrationPlan mc =
        MigrationPlan(ops.asMap().map((k, v) => MapEntry(k + 1, [v])));

    var path = await context.initDeleteDb('open_oncreate_ver_n.db');
    Database db = await openDb(path, factory, toVersion, onCreate: mc);

    for (int i = 0; i < maxVersion; i++) {
      expect(ops[i].forwardCalled, i < toVersion);
      expect(ops[i].reverseCalled, false);
      expect((mc[i + 1][0] as TestOp).forwardCalled, i < toVersion);
      expect((mc[i + 1][0] as TestOp).reverseCalled, false);
    }
    expect(await db.getVersion(), toVersion);
    await db.close();
  });

  test('onUpgrade migrates to version N', () async {
    int maxVersion = 7;
    int initialVersion = 2;
    int toVersion = 5;
    // await utils.devSetDebugModeOn(true);
    List<TestOp> ops =
        Iterable<int>.generate(maxVersion).map((i) => TestOp()).toList();

    MigrationPlan mc =
        MigrationPlan(ops.asMap().map((k, v) => MapEntry(k + 1, [v])));

    var path = await context.initDeleteDb('onupgrade_ver_n.db');
    Database db = await openDb(path, factory, initialVersion,
        onCreate: mc, onUpgrade: mc);

    for (int i = 0; i < maxVersion; i++) {
      expect(ops[i].forwardCalled, i < initialVersion);
      expect(ops[i].reverseCalled, false);
    }
    expect(await db.getVersion(), initialVersion);
    await db.close();

    //all operations reset to not called
    ops.forEach((op) {
      op.forwardCalled = false;
      op.reverseCalled = false;
    });

    db = await openDb(path, factory, toVersion, onCreate: mc, onUpgrade: mc);
    for (int i = 0; i < maxVersion; i++) {
      expect(ops[i].forwardCalled, i >= initialVersion && i < toVersion);
      expect(ops[i].reverseCalled, false);
    }
    expect(await db.getVersion(), toVersion);
    await db.close();
  });

  test('onDowngrade migrates to version N', () async {
    int maxVersion = 7;
    int toVersion = 5;
    // await utils.devSetDebugModeOn(true);
    List<TestOp> ops =
        Iterable<int>.generate(maxVersion).map((i) => TestOp()).toList();
    MigrationPlan mc =
        MigrationPlan(ops.asMap().map((k, v) => MapEntry(k + 1, [v])));

    var path = await context.initDeleteDb('ondowngrade_ver_n.db');
    Database db =
        await openDb(path, factory, maxVersion, onCreate: mc, onUpgrade: mc);

    await db.close();

    //all operations reset to not called
    ops.forEach((op) {
      op.forwardCalled = false;
      op.reverseCalled = false;
    });

    db = await openDb(path, factory, toVersion,
        onCreate: mc, onUpgrade: mc, onDowngrade: mc);
    for (int i = 0; i < maxVersion; i++) {
      expect(ops[i].forwardCalled, false);
      expect(ops[i].reverseCalled, i >= toVersion);
    }
    expect(await db.getVersion(), toVersion);
    await db.close();
  });

  test('no migrations when same version', () async {
    int maxVersion = 7;
    // await utils.devSetDebugModeOn(true);
    List<TestOp> ops =
        Iterable<int>.generate(maxVersion).map((i) => TestOp()).toList();

    MigrationPlan mc =
        MigrationPlan(ops.asMap().map((k, v) => MapEntry(k + 1, [v])));

    var path = await context.initDeleteDb('no_migrate_same_version.db');
    Database db = await openDb(path, factory, maxVersion, onCreate: mc);

    await db.close();

    //all operations reset to not called
    ops.forEach((op) {
      op.forwardCalled = false;
      op.reverseCalled = false;
    });

    db = await openDb(path, factory, maxVersion,
        onCreate: mc, onUpgrade: mc, onDowngrade: mc);
    for (int i = 0; i < maxVersion; i++) {
      expect(ops[i].forwardCalled, false);
      expect(ops[i].reverseCalled, false);
    }
    expect(await db.getVersion(), maxVersion);
    await db.close();
  });

  test('Open read-only', () async {
    // await context.devSetDebugModeOn(true);
    var path = await context.initDeleteDb('open_read_only.db');

    MigrationPlan mc = MigrationPlan({
      1: [SqlMigration("CREATE TABLE t (i INTEGER PRIMARY KEY)")],
      2: [insertValueOp(2)],
      3: [insertValueOp(3)],
      4: [insertValueOp(4)],
      5: [insertValueOp(5)],
    });

    var db = await factory.openDatabase(path,
        options: OpenDatabaseOptions(version: 2, onCreate: mc));
    expect(utils.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM t')), 1);

    await db.close();

    //Fail when attempting to upgrade on read only db
    try {
      db = await factory.openDatabase(path,
          options:
              OpenDatabaseOptions(version: 5, readOnly: true, onUpgrade: mc));
    } on DatabaseMigrationException catch (e) {
      expect(e.isReadOnlyError(), true);
      expect(e.cause.isReadOnlyError(), true);
    }

    //Succeed when no upgrade on read only db
    db = await factory.openDatabase(path,
        options:
            OpenDatabaseOptions(version: 2, readOnly: true, onUpgrade: mc));
    expect(utils.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM t')), 1);

    await db.close();
  });
}
