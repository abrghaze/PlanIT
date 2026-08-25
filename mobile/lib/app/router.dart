import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/app/shell/planit_scaffold.dart';
import 'package:planit_mobile/features/accounts/presentation/account_form_screen.dart';
import 'package:planit_mobile/features/accounts/presentation/accounts_screen.dart';
import 'package:planit_mobile/features/activity/presentation/activity_screen.dart';
import 'package:planit_mobile/features/analytics/presentation/analytics_screen.dart';
import 'package:planit_mobile/features/auth/presentation/register_screen.dart';
import 'package:planit_mobile/features/auth/presentation/sign_in_screen.dart';
import 'package:planit_mobile/features/home/presentation/home_screen.dart';
import 'package:planit_mobile/features/more/presentation/more_screen.dart';
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
      path: '/transactions/new',
      builder: (context, state) => TransactionFormScreen(
        initialType: state.uri.queryParameters['type'] == 'INCOME'
            ? TransactionType.income
            : TransactionType.expense,
      ),
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
