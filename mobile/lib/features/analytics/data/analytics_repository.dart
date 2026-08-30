import 'dart:convert';

import 'package:planit_mobile/core/database/app_database.dart';
import 'package:planit_mobile/features/analytics/data/analytics_api.dart';
import 'package:planit_mobile/features/analytics/domain/analytics_dashboard.dart';

final class AnalyticsRepository {
  const AnalyticsRepository({required this.api, required this.database});
  final AnalyticsApi api;
  final AppDatabase database;

  Future<AnalyticsDashboard> load({
    required String ownerId,
    required String accessToken,
    required AnalyticsFilter filter,
  }) async {
    try {
      final payload = await api.fetch(accessToken: accessToken, filter: filter);
      await database.saveAnalyticsDashboard(
        ownerId: ownerId,
        cacheKey: filter.cacheKey,
        payloadJson: jsonEncode(payload),
      );
      return AnalyticsDashboard.fromJson(payload);
    } catch (_) {
      final cached = await database.readAnalyticsDashboard(
        ownerId,
        filter.cacheKey,
      );
      if (cached == null) rethrow;
      final payload = Map<String, Object?>.from(
        jsonDecode(cached.payloadJson) as Map,
      );
      return AnalyticsDashboard.fromJson(payload).asCached(cached.updatedAt);
    }
  }
}
