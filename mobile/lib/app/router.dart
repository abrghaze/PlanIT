import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/app/shell/planit_scaffold.dart';
import 'package:planit_mobile/features/activity/presentation/activity_screen.dart';
import 'package:planit_mobile/features/analytics/presentation/analytics_screen.dart';
import 'package:planit_mobile/features/home/presentation/home_screen.dart';
import 'package:planit_mobile/features/more/presentation/more_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter planItRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/home',
  routes: <RouteBase>[
    ShellRoute(
      builder: (BuildContext context, GoRouterState state, Widget child) {
        return PlanItScaffold(location: state.uri.path, child: child);
      },
      routes: <RouteBase>[
        GoRoute(
          path: '/home',
          pageBuilder: (context, state) => const NoTransitionPage(child: HomeScreen()),
        ),
        GoRoute(
          path: '/activity',
          pageBuilder: (context, state) => const NoTransitionPage(child: ActivityScreen()),
        ),
        GoRoute(
          path: '/analytics',
          pageBuilder: (context, state) => const NoTransitionPage(child: AnalyticsScreen()),
        ),
        GoRoute(
          path: '/more',
          pageBuilder: (context, state) => const NoTransitionPage(child: MoreScreen()),
        ),
      ],
    ),
  ],
);
