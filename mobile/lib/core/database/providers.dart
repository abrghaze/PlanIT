import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/database/app_database.dart';

final Provider<AppDatabase> appDatabaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();
  ref.onDispose(database.close);
  return database;
});
