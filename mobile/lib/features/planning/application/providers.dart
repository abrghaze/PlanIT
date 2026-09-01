import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/auth/application/providers.dart';
import 'package:planit_mobile/core/database/providers.dart';
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
  final current = ref.watch(authControllerProvider).session;
  if (current == null) throw StateError('Authentication is required.');
  final session = await ref
      .read(authControllerProvider.notifier)
      .requireFreshSession();
  return ref
      .watch(planningRepositoryProvider)
      .load(ownerId: session.user.id, token: session.accessToken);
});
