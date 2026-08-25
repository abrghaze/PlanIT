import 'package:drift/drift.dart';
import 'package:drift/wasm.dart';

QueryExecutor openPlanItDatabase() {
  final connection = WasmDatabase.open(
    databaseName: 'planit',
    sqlite3Uri: Uri.parse('sqlite3.wasm'),
    driftWorkerUri: Uri.parse('drift_worker.js'),
  ).then((result) => result.resolvedExecutor);
  return DatabaseConnection.delayed(connection);
}
