import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/app/shell/planit_scaffold.dart';
import 'package:planit_mobile/features/accounts/presentation/account_form_screen.dart';
import 'package:planit_mobile/features/accounts/presentation/accounts_screen.dart';
import 'package:planit_mobile/features/activity/presentation/activity_screen.dart';
import 'package:planit_mobile/features/analytics/presentation/analytics_screen.dart';
import 'package:planit_mobile/features/auth/presentation/register_screen.dart';
import 'package:planit_mobile/features/auth/presentation/sign_in_screen.dart';
import 'package:planit_mobile/features/debts/presentation/debt_detail_screen.dart';
import 'package:planit_mobile/features/debts/presentation/debt_form_screen.dart';
import 'package:planit_mobile/features/debts/presentation/debts_screen.dart';
import 'package:planit_mobile/features/debts/presentation/expense_recovery_screen.dart';
import 'package:planit_mobile/features/financial_operations/presentation/pending_operations_screen.dart';
import 'package:planit_mobile/features/financial_operations/presentation/reallocation_screen.dart';
import 'package:planit_mobile/features/financial_operations/presentation/reconciliation_screen.dart';
import 'package:planit_mobile/features/financial_operations/presentation/transfer_screen.dart';
import 'package:planit_mobile/features/home/presentation/home_screen.dart';
import 'package:planit_mobile/features/more/presentation/more_screen.dart';
import 'package:planit_mobile/features/purchases/presentation/merchants_screen.dart';
import 'package:planit_mobile/features/purchases/presentation/products_screen.dart';
import 'package:planit_mobile/features/transactions/domain/transaction.dart';
import 'package:planit_mobile/features/transactions/presentation/catalog_screen.dart';
import 'package:planit_mobile/features/transactions/presentation/transaction_detail_screen.dart';
import 'package:planit_mobile/features/transactions/presentation/transaction_form_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter publicRouter = GoRouter(
  initialLocation: '/sign-in',
  routes: <RouteBase>[
    GoRoute(
      path: '/sign-in',
      builder: (context, state) => const SignInScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
  ],
);

final GoRouter authenticatedRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/home',
  routes: <RouteBase>[
    GoRoute(
      path: '/debts',
      builder: (context, state) => const DebtsScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: 'new',
          builder: (context, state) => const DebtFormScreen(),
        ),
        GoRoute(
          path: ':debtId',
          builder: (context, state) =>
              DebtDetailScreen(debtId: state.pathParameters['debtId']!),
        ),
      ],
    ),
    GoRoute(
      path: '/transactions/:transactionId/share',
      builder: (context, state) => ExpenseRecoveryScreen(
        transactionId: state.pathParameters['transactionId']!,
        kind: ExpenseRecoveryKind.share,
      ),
    ),
    GoRoute(
      path: '/transactions/:transactionId/refund',
      builder: (context, state) => ExpenseRecoveryScreen(
        transactionId: state.pathParameters['transactionId']!,
        kind: ExpenseRecoveryKind.refund,
      ),
    ),
    GoRoute(
      path: '/accounts',
      builder: (context, state) => const AccountsScreen(),
      routes: <RouteBase>[
        GoRoute(
          path: 'new',
          builder: (context, state) => const AccountFormScreen(),
        ),
        GoRoute(
          path: ':accountId/edit',
          builder: (context, state) =>
              AccountFormScreen(accountId: state.pathParameters['accountId']),
        ),
      ],
    ),
    GoRoute(
      path: '/merchants',
      builder: (context, state) => const MerchantsScreen(),
    ),
    GoRoute(
      path: '/products',
      builder: (context, state) => const ProductsScreen(),
    ),
    GoRoute(
      path: '/transactions/new',
      builder: (context, state) => TransactionFormScreen(
        initialType: state.uri.queryParameters['type'] == 'INCOME'
            ? TransactionType.income
            : TransactionType.expense,
      ),
    ),
    GoRoute(
      path: '/transfers/new',
      builder: (context, state) => const TransferScreen(),
    ),
    GoRoute(
      path: '/reconciliations/new',
      builder: (context, state) => ReconciliationScreen(
        initialAccountId: state.uri.queryParameters['accountId'],
      ),
    ),
    GoRoute(
      path: '/reallocations/new',
      builder: (context, state) => const ReallocationScreen(),
    ),
    GoRoute(
      path: '/pending-operations',
      builder: (context, state) => const PendingOperationsScreen(),
    ),
    GoRoute(
      path: '/transactions/:transactionId',
      builder: (context, state) => TransactionDetailScreen(
        transactionId: state.pathParameters['transactionId']!,
      ),
    ),
    GoRoute(
      path: '/transactions/:transactionId/edit',
      builder: (context, state) => TransactionFormScreen(
        transactionId: state.pathParameters['transactionId'],
      ),
    ),
    GoRoute(
      path: '/catalog',
      builder: (context, state) => const CatalogScreen(),
    ),
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        return PlanItScaffold(location: state.uri.path, child: child);
      },
      routes: <RouteBase>[
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: '/activity',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: ActivityScreen()),
        ),
        GoRoute(
          path: '/analytics',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: AnalyticsScreen()),
        ),
        GoRoute(
          path: '/more',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: MoreScreen()),
        ),
      ],
    ),
  ],
);
