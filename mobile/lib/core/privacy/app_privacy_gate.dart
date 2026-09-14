import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/privacy/app_privacy_controller.dart';

class AppPrivacyGate extends ConsumerWidget {
  const AppPrivacyGate({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacy = ref.watch(appPrivacyControllerProvider);
    if (!privacy.ready || !privacy.locked) return child;
    return Stack(
      children: <Widget>[
        child,
        Positioned.fill(
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(PlanItSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Icon(
                        Icons.lock_rounded,
                        size: 52,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: PlanItSpacing.md),
                      Text(
                        'PlanIT is locked',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: PlanItSpacing.xs),
                      const Text(
                        'Use your fingerprint or device screen lock to view your financial information.',
                        textAlign: TextAlign.center,
                      ),
                      if (privacy.errorMessage != null) ...<Widget>[
                        const SizedBox(height: PlanItSpacing.md),
                        Text(
                          privacy.errorMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      const SizedBox(height: PlanItSpacing.lg),
                      FilledButton.icon(
                        onPressed: () => ref
                            .read(appPrivacyControllerProvider.notifier)
                            .unlock(),
                        icon: const Icon(Icons.fingerprint_rounded),
                        label: const Text('Unlock PlanIT'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
