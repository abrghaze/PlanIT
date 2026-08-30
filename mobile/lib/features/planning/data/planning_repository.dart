import 'dart:convert';

import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/features/planning/data/planning_api.dart';
import 'package:planit_mobile/features/planning/domain/planning.dart';

final class PlanningRepository {
  const PlanningRepository({required this.api, required this.database});
  final PlanningApi api;
  final AppDatabase database;

  Future<PlanningDashboard> load({
    required String ownerId,
    required String token,
  }) async {
    try {
      final payload = await api.fetch(token);
      await database.savePlanningSnapshot(
        ownerId: ownerId,
        payloadJson: jsonEncode(payload),
      );
      return PlanningDashboard.fromJson(payload);
    } catch (_) {
      final cached = await database.readPlanningSnapshot(ownerId);
      if (cached == null) rethrow;
      return PlanningDashboard.fromJson(
        Map<String, Object?>.from(jsonDecode(cached.payloadJson) as Map),
        cachedAt: cached.updatedAt,
      );
    }
  }
}
