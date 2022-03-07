# sqflite_migration_plan

Flexible migrations (upgrade and downgrade) for your Flutter [sqflite](https://pub.dev/packages/sqflite) database. Alter schemas, seed tables, and update data with a concise and readable syntax.  

## Quickstart

Specify a MigrationPlan, which is a group of Migrations each associated with a version.

```dart
MigrationPlan myMigrationPlan = MigrationPlan({

  2: [ //Migration for v2: create a table using SQL Operation
    SqlMigration('''CREATE TABLE $_table ( $_my_columns )''')
                   reverseSql: 'DROP TABLE $_table')// Reverse drops the table
  ],
 
  3: [  //Migration for v3: add initial records using custom function
    Migration(Operation((db) async {
        _insertRecord(Entity(null, "Mordecai", "Pitcher"), db);
        _insertRecord(Entity(null, "Tommy", "Pitcher"), db);
        _insertRecord(Entity(null, "Max", "Center Field"), db);
    }), reverse: Operation((db) async => db.execute('DELETE FROM $_table')))
  ],

  4: [// Two migration for v4: add a column, set initial values
    // a custom Migration defines desired behavior of adding/removing col
    AddColumnMigration(_table, _columnHome['name']!, _columnHome['def']!,
        [_columnId, _columnName, _columnDesc]),
    Migration.fromOperationFunctions((db) async => db.execute(
        'UPDATE $_table SET ${_columnHome['name']} = \'Terre Haute\'')),
    // Omit the reverse; no action on downgrade of this operation
  ]
});
```

Then, provide this migration plan as `onCreate`, `onUpgrade`, and/or `onDowngrade` arguments (as needed) to the sqflite `openDatabase` function.

```dart
await openDatabase(
    join(documentsDirectory.path, _databaseName),
    version: _databaseVersion,
    onCreate: myMigrationPlan, // handle initial upgrade tasks
    onUpgrade: myMigrationPlan, // and incremental upgrade tasks
    onDowngrade: myMigrationPlan, // and downgrading
);
```

The specified migration plan will then assume control of migrating a database on open, selecting then executing in order the appropriate operations based on the existing database version and the version specified on open.

See the [example project](https://github.com/ilikerobots/sqflite_migration_plan/tree/main/example) for a more complete illustration.

## Concepts: MigrationPlan and Migration

Conceptually, A `MigrationPlan` is a map, keyed by database versions, with values as ordered lists of zero or more migrations.  Each list of migrations associated to a database version cumulatively serve to upgrade to (or downgrade from) that corresponding version.  

A `Migration` is conceptually a pair of functions: a forward function which effects a database change and a reverse function that undoes this change.  

## Building a Migration Plan

Construct a `MigrationPlan` with a Map associating integer database versions with a `List<Migration>`.  The list of migrations are given in the order they are to run when upgrading (they will run in reverse order on downgrade).


Individual migrations can be built via constructor, providing the minimum argument of a single `Operation`.  By default, reverse operations are considered *No Op* (see *Downgrading* section for additional info).

Alternatively, custom migration classes extending/implementing Migration may be utilized.  One such example, `SqlMigration` whose operations execute SQL, is currently provided.

Custom migrations may perform tasks other than directly modifying a database (e.g. logging/reporting) but care should be taken introducing such side-effects.  While failed migrations will not commit to the database, any non-database side-effects will persist in the event of migration failure.

## Errors

To avoid errors, migrations should be coded as defensively as possible, either acting on guaranteed states of the database or appropriately handling potential errors.  

When authoring migration operations, it is important to take into account what changes to the database may have been made during the lifetime of an application.  Generally, this means taking into account changes to database *contents*, though it is conceivable albeit unlikely that your application runtime can modify your database schema.

### Handling Errors

While it is expected that migration errors can and should be fully avoidable with reasonable care, this package nonetheless provides tools to assist in handling and recovering from migration errors.

An error occurs when any Operation invocation throws an exception. This commonly would be a `DatabaseException` but could in fact be any exception as dictated by your operation code.

When an Operation throws an exception, the Migration containing this Operation will handle the exception based on the value of the Operation's errorStrategy and/or reverseErrorStrategy.  By default, the Migration's error strategy is `Throw` but this can be specified by providing the parameter `errorStrategy`.  The reverse operation's error strategy is assumed to the same as `errorStrategy`, but can be specified distinctly using `reverseErrorStrategy`.

#### Throw strategy (default)

When an Operation's error strategy for a given operation is `Throw`, an encountered exception is captured and encapsulated in a `DatabaseMigrationException`, with the original underlying exception assigned to the `cause` field.  Additional information, such as the specific version that encountered the error, is included in the exception.  `DatabaseMigrationException` is itself a `DatabaseException`, so it may be inspected using that interface directly.

The exception is handled normally by sqflite's `openDatabase()` method, which encapsulates the migration procedure in a transaction. A thrown exception in an operation will cancel the _entire_ onCreate, onUpgrade, or onDowngrade database transaction, leaving the database untouched from its original state.

Note however, that any non-database side-effects contained in operations that have run in the course of a failed migration will be persistent.

#### Ignore

The exception is ''squashed'' and the migration will continue as if no error had occurred.  While ignoring a migration error would normally be inadvisable, it is possible are certain circumstances this strategy may be reasonable.

## Downgrading

Per [sqflite documentation](https://pub.dev/documentation/sqflite/latest/sqflite/openDatabase.html), the circumstances requiring a downgrade should be quite rare and "you should try to avoid this scenario". Indeed, except in development scenarios, I have been unable to imagine the circumstances in which application code would be aware of the migrations for a particular version of a database and yet also wish to downgrade that database to a prior version.  Ideas welcome. 

At the risk of stating the obvious, it must be noted that database migrations would **not**  be executed as a result of a straightforward downgrade of an *application* from version Q to P, as the downgrade migrations for the version Q would not exist in the downgraded application version P code. 

So, is there a point to providing migration reverse operations? Maybe. If it is useful, then it would likely be as a result of your testing or development practices rather than deployed production code.

The most obvious benefit of a reverse migration is that it simply reduces iteration time when developing forward migrations. Instead of restoring a database to a fixed state between iterations, reverse migrations will allow a developer to ping-pong between database versions quickly (with hot-restarts).  

Another possible scenario would be a team of testers or developers switching branches, where having a downgrade-able migration would allow non-destructively reverting databases before leaving a branch.

Unfortunately, both these examples render development-centric code residue in production code, which may be undesirable.   

Bottom line: I've spent several hours writing this reverse migration code and boy I'd be jazzed if someone would identify some way it's useful.  


### Reverse operations

The default reverse for all Operations is `noop` (no-operation). If you do find it useful to provide reverse operations, keep in mind that an effective reverse operation need not always (and often cannot always) be an inverse operation to the forward.  Rather the goal is to bring the database back to an effective state for the downgraded application code and to a state at which the subsequent migration(s) can be reapplied.

Idempotent operations are common examples where reverse operations might often be omitted.  For example, if a certain operation serves to capitalize the first letter for all values of a column, the reverse of that operation might simply be a no-op.  Likewise, while a `CREATE TABLE` operation should be reversed with corresponding `DROP TABLE` operation, the idempotent `CREATE TABLE IF NOT EXISTS` operation may not require a corresponding `DROP`.

## Capturing Results

Information obtained during the course of migration can be captured by custom Operations.  These can be recorded externally (e.g. a log file, json files) or assigned to a field of the operation.  The field can subsequently be accessed after migration.  An [example of capturing results](https://github.com/ilikerobots/sqflite_migration_plan/tree/main/example/lib/src/capture_result_migration.dart) is in the [example app](https://github.com/ilikerobots/sqflite_migration_plan/tree/main/example).

## Future enhancements

I would like to include a library of Migrations and Operations for common tasks such as adding columns, renaming columns/tables, 
