import 'package:sqflite_migration_plan/migration/sql.dart';

class AddColumnMigration extends SqlMigration {
  final String tableName;
  final String colName;
  final String colDefinition;

  AddColumnMigration(this.tableName, this.colName, this.colDefinition,
      List<Map<String, String>> priorColumns)
      : super('''
          ALTER TABLE $tableName
          ADD $colName $colDefinition
          ''', reverseSql: '''
          PRAGMA foreign_keys=off;
          BEGIN TRANSACTION;

          ALTER TABLE employees RENAME TO _employees_old;

          CREATE TABLE employees
          ( employee_id INTEGER PRIMARY KEY AUTOINCREMENT,
            last_name VARCHAR NOT NULL,
            first_name VARCHAR
          );
          
          INSERT INTO employees (employee_id, last_name, first_name)
            SELECT employee_id, last_name, first_name
            FROM _employees_old;
          
          COMMIT;
          PRAGMA foreign_keys=on;
          ''');
}
