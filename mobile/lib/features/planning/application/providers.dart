import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/auth/application/providers.dart';
import 'package:planit_mobile/core/data_revision.dart';
import 'package:planit_mobile/core/database/providers.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/features/planning/data/planning_api.dart';
import 'package:planit_mobile/features/planning/data/planning_repository.dart';
import 'package:planit_mobile/features/planning/domain/planning.dart';

final planningApiProvider = Provider<PlanningApi>(
  (ref) => PlanningApi(ref.watch(apiClientProvider)),
);

final planningRepositoryProvider = Provider<PlanningRepository>(
  (ref) => PlanningRepository(
    api: ref.watch(planningApiProvider),
    database: ref.watch(appDatabaseProvider),
  ),
);

final planningDashboardProvider = FutureProvider<PlanningDashboard>((
  ref,
) async {
  ref.watch(financialDataRevisionProvider);
  final auth = ref.watch(authControllerProvider);
  final current = auth.session;
  if (current == null) throw StateError('Authentication is required.');
  final repository = ref.watch(planningRepositoryProvider);
  if (auth.offline) return repository.loadCached(current.user.id);
  try {
    final session = await ref
        .read(authControllerProvider.notifier)
        .requireFreshSession();
    return repository.load(ownerId: session.user.id, token: session.accessToken);
  } on AppException catch (error) {
    if (!error.isNetworkFailure) rethrow;
    return repository.loadCached(current.user.id);
  }
});
