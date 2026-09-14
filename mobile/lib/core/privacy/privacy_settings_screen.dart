import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/privacy/app_privacy_controller.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacy = ref.watch(appPrivacyControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Security & privacy')),
      body: ListView(
        padding: const EdgeInsets.all(PlanItSpacing.lg),
        children: <Widget>[
          Card(
            child: SwitchListTile.adaptive(
              value: privacy.enabled,
              onChanged: !privacy.ready
                  ? null
                  : (enabled) async {
                      final controller = ref.read(
                        appPrivacyControllerProvider.notifier,
                      );
                      final changed = enabled
                          ? await controller.enable()
                          : await controller.disable();
                      if (!changed && context.mounted) {
                        final message = ref
                            .read(appPrivacyControllerProvider)
                            .errorMessage;
                        if (message != null) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(message)));
                        }
                      }
                    },
              secondary: const Icon(Icons.fingerprint_rounded),
              title: const Text('Lock PlanIT with this phone'),
              subtitle: Text(
                privacy.available
                    ? 'Require fingerprint or your device screen lock whenever PlanIT returns to the foreground.'
                    : 'Set up a screen lock or fingerprint on this phone to enable this option.',
              ),
            ),
          ),
          const SizedBox(height: PlanItSpacing.md),
          const Card(
            child: ListTile(
              leading: Icon(Icons.visibility_off_outlined),
              title: Text('Private data stays private'),
              subtitle: Text(
                'The lock blocks access after PlanIT leaves the foreground. Your saved data remains on the device for offline use.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
