import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/app/router.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/auth/application/auth_state.dart';
import 'package:planit_mobile/core/design_system/app_theme.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/features/transactions/application/transaction_controller.dart';

class PlanItApp extends ConsumerStatefulWidget {
  const PlanItApp({super.key});

  @override
  ConsumerState<PlanItApp> createState() => _PlanItAppState();
}

class _PlanItAppState extends ConsumerState<PlanItApp> {
  static const Duration _foregroundRetryInterval = Duration(seconds: 30);

  late final AppLifecycleListener _lifecycleListener;
  Timer? _retryTimer;
  String? _activeOwnerId;
  var _isForeground = true;
  var _synchronizationScheduled = false;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: _resumeForegroundWork,
      onShow: _resumeForegroundWork,
      onPause: _pauseForegroundWork,
      onHide: _pauseForegroundWork,
      onDetach: _pauseForegroundWork,
    );
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    _lifecycleListener.dispose();
    super.dispose();
  }

  void _handleAuthState(AuthState auth) {
    final ownerId = auth.session?.user.id;
    if (ownerId == _activeOwnerId) {
      if (ownerId != null && _isForeground) {
        _startForegroundRetries();
      }
      return;
    }

    _activeOwnerId = ownerId;
    if (ownerId == null) {
      _retryTimer?.cancel();
      _retryTimer = null;
      return;
    }
    if (_isForeground) {
      _startForegroundRetries();
      _scheduleSynchronization();
    }
  }

  void _resumeForegroundWork() {
    _isForeground = true;
    _startForegroundRetries();
    _scheduleSynchronization();
  }

  void _pauseForegroundWork() {
    _isForeground = false;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  void _startForegroundRetries() {
    if (!_isForeground || _activeOwnerId == null || _retryTimer != null) {
      return;
    }
    _retryTimer = Timer.periodic(
      _foregroundRetryInterval,
      (_) => _scheduleSynchronization(),
    );
  }

  void _scheduleSynchronization() {
    final ownerId = _activeOwnerId;
    if (!mounted || !_isForeground || ownerId == null || _synchronizationScheduled) {
      return;
    }
    _synchronizationScheduled = true;
    unawaited(Future<void>.microtask(() async {
      try {
        if (!mounted ||
            !_isForeground ||
            ref.read(authControllerProvider).session?.user.id != ownerId) {
          return;
        }
        await ref.read(transactionControllerProvider.notifier).refresh(
          silent: true,
          suppressNetworkErrors: true,
        );
      } finally {
        _synchronizationScheduled = false;
      }
    }));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(
      authControllerProvider,
      (_, next) => _handleAuthState(next),
      fireImmediately: true,
    );
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
