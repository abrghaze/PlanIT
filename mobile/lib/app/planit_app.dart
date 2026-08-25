import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/app/router.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/design_system/app_theme.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';

class PlanItApp extends ConsumerWidget {
  const PlanItApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (!auth.initialized) {
      return const _BootstrapApp();
    }

    return MaterialApp.router(
      key: ValueKey<bool>(auth.isAuthenticated),
      title: 'PlanIT',
      debugShowCheckedModeBanner: false,
      theme: PlanItTheme.light,
      darkTheme: PlanItTheme.dark,
      themeMode: ThemeMode.system,
      routerConfig: auth.isAuthenticated ? authenticatedRouter : publicRouter,
    );
  }
}

class _BootstrapApp extends StatelessWidget {
  const _BootstrapApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PlanIT',
      debugShowCheckedModeBanner: false,
      theme: PlanItTheme.light,
      darkTheme: PlanItTheme.dark,
      home: const Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF0B1739), PlanItColors.primary],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 58,
                  color: Colors.white,
                ),
                SizedBox(height: PlanItSpacing.md),
                Text(
                  'PlanIT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: PlanItSpacing.lg),
                SizedBox.square(
                  dimension: 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
