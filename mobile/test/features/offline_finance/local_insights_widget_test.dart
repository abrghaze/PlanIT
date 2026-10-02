import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:planit_mobile/core/auth/application/providers.dart';
import 'package:planit_mobile/core/auth/data/auth_repository.dart';
import 'package:planit_mobile/features/analytics/application/providers.dart';
import 'package:planit_mobile/features/analytics/presentation/analytics_screen.dart';
import 'package:planit_mobile/features/offline_finance/application/providers.dart';
import 'package:planit_mobile/features/transactions/application/providers.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';
import 'local_report_test.dart' show entry;

class _Auth extends Mock implements AuthRepository {}

void main() {
  testWidgets(
    'local analytics works without server requests and updates after a phone write',
    (tester) async {
      final auth = _Auth();
      when(auth.restore).thenAnswer(
        (_) async => const AuthRestoreResult(session: null, offline: true),
      );
      final changes = StreamController<List<LedgerTransaction>>();
      addTearDown(changes.close);
      var serverReads = 0;
      final router = GoRouter(
        initialLocation: '/analytics',
        routes: [
          GoRoute(
            path: '/analytics',
            builder: (_, _) => const Scaffold(body: AnalyticsScreen()),
          ),
          GoRoute(
            path: '/transactions/:id',
            builder: (_, state) =>
                Scaffold(body: Text('Opened ${state.pathParameters['id']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            localClockProvider.overrideWithValue(DateTime(2026, 10, 10)),
            transactionsProvider.overrideWith((ref) async* {
              yield [entry('coffee', '20')];
              yield* changes.stream;
            }),
            transactionCategoriesProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            analyticsDashboardProvider.overrideWith((ref, filter) {
              serverReads++;
              throw StateError('Offline');
            }),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('On this phone'), findsOneWidget);
      expect(find.text('20.00 MAD'), findsWidgets);
      expect(serverReads, 0);
      changes.add([
        entry('coffee', '35', pending: 'POST', status: TransactionStatus.draft),
      ]);
      await tester.pumpAndSettle();
      expect(find.text('35.00 MAD'), findsWidgets);
      expect(find.textContaining('1 local changes'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('View all 1 source records'),
        300,
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View all 1 source records'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('View all 1 source records'));
      await tester.pumpAndSettle();
      expect(find.text('1 source records'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Expense').last);
      await tester.pumpAndSettle();
      expect(find.text('Opened coffee'), findsOneWidget);
      expect(serverReads, 0);
    },
  );

  testWidgets(
    'small phone with large text can read and change local report months',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = _Auth();
      when(auth.restore).thenAnswer(
        (_) async => const AuthRestoreResult(session: null, offline: true),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            localClockProvider.overrideWithValue(DateTime(2026, 10, 10)),
            transactionsProvider.overrideWith(
              (ref) => Stream.value([entry('expense', '500')]),
            ),
            transactionCategoriesProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const Scaffold(body: AnalyticsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('Previous month'));
      await tester.pumpAndSettle();
      expect(find.text('September 2026'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
