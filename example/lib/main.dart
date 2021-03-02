import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_migration_plan/migration/sql.dart';
import 'package:sqflite_migration_plan/sqflite_migration_plan.dart';
import 'package:sqflite_migration_plan_example/src/add_column_migration.dart';
import 'package:sqflite_migration_plan_example/src/capture_result_migration.dart';

import 'src/entity.dart';

void main() {
  runApp(MyApp());
}

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

      3: [
        Migration(Operation((db) async {
          _insertRecord(Entity(null, "Mordecai", "Pitcher"), db);
          _insertRecord(Entity(null, "Tommy", "Pitcher"), db);
          _insertRecord(Entity(null, "Max", "Center Field"), db);
        }), reverse: Operation((db) async => db.execute('DELETE FROM $_table')))
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
    } on DatabaseMigrationException catch (err) {
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
        _databaseVersion: [Migration(Operation(noop))]
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
    } catch (err) {
      print("Unknown Error opening database: $err");
      // TODO handle non database migration errors gracefully
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

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;

  MyHomePage({Key? key, this.title = "My App"}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    // get entities from db, with addl delay for demonstration
    Future<List<Entity>> _entities = Future.delayed(
        Duration(milliseconds: 500), MyRepository.instance.getEntities);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: FutureBuilder<List<Entity>>(
          future: _entities, // a previously-obtained Future<String> or null
          builder:
              (BuildContext context, AsyncSnapshot<List<Entity>> snapshot) {
            List<Widget> children;
            if (snapshot.hasData) {
              children = <Widget>[
                if ((snapshot.data?.length ?? 0) > 0)
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.all(24),
                      itemCount: snapshot.data?.length ?? 0,
                      itemBuilder: (BuildContext context, int index) {
                        return Container(
                          padding: EdgeInsets.all(8),
                          color: Colors.blue,
                          child: Center(
                              child: Column(
                            children: [
                              Text(
                                snapshot.data![index].name,
                                textScaleFactor: 1.3,
                                style: TextStyle(color: Colors.white),
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(4),
                                    color: Colors.amberAccent,
                                    child: Text(
                                      'Position: ${snapshot.data![index].position}',
                                    ),
                                  ),
                                  if (snapshot.data![index].hometown != null)
                                    Container(
                                      padding: EdgeInsets.all(4),
                                      color: Colors.tealAccent,
                                      child: Text(
                                        'Home: ${snapshot.data![index].hometown}',
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          )),
                        );
                      },
                      separatorBuilder: (BuildContext context, int index) =>
                          const Divider(),
                    ),
                  )
                else
                  Text("Database is empty")
              ];
            } else if (snapshot.hasError) {
              children = <Widget>[
                Icon(
                  Icons.error_outline,
                  color: Colors.red,
                  size: 60,
                ),
                if (snapshot.error is DatabaseException &&
                    (snapshot.error as DatabaseException).isNoSuchTableError())
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('Error: Table does not exist!'),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text('Error: ${snapshot.error}'),
                  )
              ];
            } else {
              children = <Widget>[
                SizedBox(
                  child: CircularProgressIndicator(),
                  width: 60,
                  height: 60,
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('Awaiting result...'),
                )
              ];
            }
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: children,
              ),
            );
          },
        ),
      ),
    );
  }
}
