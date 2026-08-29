import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/auth/application/providers.dart';
import 'package:planit_mobile/features/debts/data/debts_api.dart';
import 'package:planit_mobile/features/debts/domain/debt.dart';

final debtsApiProvider = Provider<DebtsApi>(
  (ref) => DebtsApi(ref.watch(apiClientProvider)),
);

final peopleProvider = FutureProvider<List<Person>>((ref) async {
  final session = await ref
      .read(authControllerProvider.notifier)
      .requireFreshSession();
  return ref
      .read(debtsApiProvider)
      .fetchPeople(accessToken: session.accessToken);
});

final debtsProvider = FutureProvider<List<Debt>>((ref) async {
  final session = await ref
      .read(authControllerProvider.notifier)
      .requireFreshSession();
  return ref
      .read(debtsApiProvider)
      .fetchDebts(ownerId: session.user.id, accessToken: session.accessToken);
});
