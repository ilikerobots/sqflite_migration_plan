import 'package:sqflite/sqflite.dart';

Future<Database> openDb(
  String path,
  DatabaseFactory factory,
  int? toVersion, {
  OnDatabaseCreateFn? onCreate,
  OnDatabaseVersionChangeFn? onUpgrade,
  OnDatabaseVersionChangeFn? onDowngrade,
}) async {
  return await factory.openDatabase(path,
      options: OpenDatabaseOptions(
        version: toVersion,
        onCreate: onCreate,
        onUpgrade: onUpgrade,
        onDowngrade: onDowngrade,
      ));
}
