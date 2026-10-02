import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/auth/application/providers.dart';
import 'package:planit_mobile/core/data_revision.dart';
import 'package:planit_mobile/core/database/providers.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/core/money/money.dart';
import 'package:planit_mobile/features/accounts/application/providers.dart';
import 'package:planit_mobile/features/offline_finance/application/providers.dart';
import 'package:planit_mobile/features/planning/data/planning_api.dart';
import 'package:planit_mobile/features/planning/data/planning_repository.dart';
import 'package:planit_mobile/features/planning/domain/planning.dart';

/// Local linked-account progress updates even while the planning snapshot is
/// cached. Manual allocations remain as last saved by the server.
final localPlanningDashboardProvider = Provider<AsyncValue<PlanningDashboard>>((
  ref,
) {
  final dashboard = ref.watch(planningDashboardProvider);
  final accounts = ref.watch(accountsProvider).value;
  final pending = ref.watch(pendingAccountBalancesProvider);
  if (accounts == null) return dashboard;
  final balances = {
    for (final account in accounts)
      account.id:
          account.calculatedBalance +
          (pending[account.id]?.delta ?? Money.zero(account.currency)),
  };
  return dashboard.whenData(
    (value) => PlanningDashboard(
      rules: value.rules,
      totals: value.totals,
      upcoming: value.upcoming,
      cachedAt: value.cachedAt,
      goals: [
        for (final goal in value.goals)
          if (balances[goal.linkedAccountId] case final balance?)
            goal.withLocalBalance(balance)
          else
            goal,
      ],
    ),
  );
});

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
    return await repository.load(
      ownerId: session.user.id,
      token: session.accessToken,
    );
  } on AppException catch (error) {
    if (!error.isNetworkFailure) rethrow;
    return repository.loadCached(current.user.id);
  }
});
