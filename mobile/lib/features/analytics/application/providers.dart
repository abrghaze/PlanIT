import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/auth/application/providers.dart';
import 'package:planit_mobile/core/data_revision.dart';
import 'package:planit_mobile/core/database/providers.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/features/analytics/data/analytics_api.dart';
import 'package:planit_mobile/features/analytics/data/analytics_repository.dart';
import 'package:planit_mobile/features/analytics/domain/analytics_dashboard.dart';

final analyticsRepositoryProvider = Provider<AnalyticsRepository>(
  (ref) => AnalyticsRepository(
    api: AnalyticsApi(ref.watch(apiClientProvider)),
    database: ref.watch(appDatabaseProvider),
  ),
);

final analyticsDashboardProvider =
    FutureProvider.family<AnalyticsDashboard, AnalyticsFilter>((
      ref,
      filter,
    ) async {
      ref.watch(financialDataRevisionProvider);
      final auth = ref.watch(authControllerProvider);
      final current = auth.session;
      if (current == null) throw StateError('Authentication is required.');
      final repository = ref.watch(analyticsRepositoryProvider);
      if (auth.offline) {
        return repository.loadCached(ownerId: current.user.id, filter: filter);
      }
      try {
        final session = await ref
            .read(authControllerProvider.notifier)
            .requireFreshSession();
        return await repository.load(
          ownerId: session.user.id,
          accessToken: session.accessToken,
          filter: filter,
        );
      } on AppException catch (error) {
        if (!error.isNetworkFailure) rethrow;
        return repository.loadCached(ownerId: current.user.id, filter: filter);
      }
    });
