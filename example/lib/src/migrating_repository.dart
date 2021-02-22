import 'dart:async';
import 'dart:core';
import 'dart:io' show Directory;

import 'package:example/src/capture_result_migration.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart'
    show getApplicationDocumentsDirectory;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_migration_plan/migration/sql.dart';
import 'package:sqflite_migration_plan/sqflite_migration_plan.dart';

import 'add_column_migration.dart';
import 'entity.dart';

class MyRepository {
  static final _databaseVersion = 4; // manipulate to perform upgrade/downgrade
  static final _resetDB = false; // for development: reset the database
  static final _databaseName = "my_database.db";
  static final _table = 'my_table';

  static final _columnId = {
    'name': 'id',
    'def': 'INTEGER PRIMARY KEY AUTOINCREMENT'
  };
  static final _columnName = {'name': 'name', 'def': 'TEXT NOT NULL'};
  static final _columnDesc = {'name': 'desc', 'def': 'TEXT NOT NULL'};
  static final _columnHome = {'name': 'home', 'def': 'TEXT'};

  MyRepository._privateConstructor();

  static final MyRepository instance = MyRepository._privateConstructor();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  _initDatabase() async {
    //Build a migration course for this database
    MigrationPlan myMigrationPlan = MigrationPlan({
      //Migration for v2: create a table using SQL Operation
      2: [
        SqlMigration('''CREATE TABLE $_table (
            ${_columnId['name']} ${_columnId['def']},
            ${_columnName['name']} ${_columnName['def']},
            ${_columnDesc['name']} ${_columnDesc['def']}
            )''',
            // Reverse drops the table
            reverseSql: 'DROP TABLE $_table')
      ],

      //Migration for v3: add initial records using custom function
      3: [
        Migration.fromOperationFunctions((db) async {
          _insertRecord(Entity(null, "Mordecai", "Pitcher"), db);
          _insertRecord(Entity(null, "Tommy", "Pitcher"), db);
          _insertRecord(Entity(null, "Max", "Center Field"), db);
          return Future.value(null);
        }, reverseOp: (db) async => db.execute('DELETE FROM $_table'))
      ],

      // Migration for v4: add a column, seed data
      4: [
        // custom subclass of Operation defines behavior adding/removing column
        AddColumnMigration(_table, _columnHome['name']!, _columnHome['def']!,
            [_columnId, _columnName, _columnDesc]),
        // This migration captures and stores results for later use
        Migration(SetColumnDefaultOperation(
            _table, _columnHome['name']!, "Terre Haute"))
      ],
    });

    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    if (_resetDB)
      await deleteDatabase(join(documentsDirectory.path, _databaseName));
    try {
      await Sqflite.setDebugModeOn(true);
      Database db = await openDatabase(
        join(documentsDirectory.path, _databaseName),
        version: _databaseVersion,
        onCreate: myMigrationPlan, // handle initial upgrade tasks
        onUpgrade: myMigrationPlan, // and incremental upgrade tasks
        onDowngrade: myMigrationPlan, // and downgrading

        // alternatively downgrade can be handled by deleting the db and
        // re-upgrading to desired version, but this is obviously destructive
        // onDowngrade: onDatabaseDowngradeDelete,
      );

      int currentVersion = await db.getVersion();
      print("Database opened at version $currentVersion");

      //An example of inspecting results of a migration
      SetColumnDefaultOperation updateOp =
          myMigrationPlan[4][1].forward as SetColumnDefaultOperation;
      print("Num records set to initial value: ${updateOp.result ?? 0}");

      return db;
    } catch (err) {
      if (err is DatabaseMigrationException) {
        // A migration error occurred. Migrations should be carefully
        // crafted to avoid failure, so if we've gotten to this point we will
        // likely need to do some serious cleanup.
        //
        // We may inspect .cause exception for clues as to what went wrong.
        //
        // Note that the database version now remains at its pre-MigrationCourse
        // state, However, any non-database side-effects of migrations will
        // remain.
        //
        // Some possible options for recovery:
        // * Delete the database and re-upgrade
        // * Reopen the database without upgrade
        // * Attempt a secondary corrective MigrationCourse
        // * Give up and inform user of the bad news

        print("Migration failed at v${err.problemVersion}: ${err.cause}");

        // A simple recovery course that sets the db to the latest version,
        // equivalent to ignoring migration problems. NB! You should likely make
        // a real attempt to bring the database back into shape.
        MigrationPlan recoveryCourse = MigrationPlan({
          _databaseVersion: [Migration.fromOperationFunctions(Operation(noop))]
        });

        Database db = await openDatabase(
          join(documentsDirectory.path, _databaseName),
          version: _databaseVersion,
          onCreate: recoveryCourse,
          onUpgrade: recoveryCourse,
          onDowngrade: recoveryCourse,
        );
        print("Database version forcibly set to $_databaseVersion");
        return db;
      } else {
        print("Error opening database: $err");
        // TODO handle gracefully
      }
    }
  }

  Future _insertRecord(Entity e, Database db) async {
    return db.insert(
      _table,
      {_columnName['name']!: e.name, _columnDesc['name']!: e.position},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Entity>> getEntities() async {
    Database db = await database;
    final List<Map<String, dynamic>> maps = await db.query(_table);

    return List.generate(maps.length, (i) {
      return Entity(
        maps[i][_columnId['name']],
        maps[i][_columnName['name']],
        maps[i][_columnDesc['name']],
        maps[i][_columnHome['name']],
      );
    });
  }
}
