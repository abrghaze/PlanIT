import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/auth/application/providers.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/core/errors/app_exception.dart';
import 'package:planit_mobile/features/settings/data/privacy_api.dart';
import 'package:planit_mobile/features/settings/data/privacy_file_saver.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _busy = false;

  PrivacyApi get _api => PrivacyApi(ref.read(apiClientProvider));

  Future<void> _download(
    Future<PrivacyDownload> Function(String) action,
  ) async {
    setState(() => _busy = true);
    try {
      final session = await ref
          .read(authControllerProvider.notifier)
          .requireFreshSession();
      final download = await action(session.accessToken);
      final savedAt = await savePrivacyFile(download.filename, download.bytes);
      _message('Export saved to $savedAt');
    } on AppException catch (error) {
      _message(error.message, error: true);
    } on UnsupportedError catch (error) {
      _message(
        error.message?.toString() ?? 'Export is unavailable.',
        error: true,
      );
    } on Object {
      _message('PlanIT could not save the export.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteProfile() async {
    final request = await showDialog<({String password, String confirmation})>(
      context: context,
      builder: (context) => const _DeleteProfileDialog(),
    );
    if (request == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final controller = ref.read(authControllerProvider.notifier);
      final session = await controller.requireFreshSession();
      await _api.deleteProfile(
        session.accessToken,
        password: request.password,
        confirmation: request.confirmation,
      );
      await controller.logout();
    } on AppException catch (error) {
      _message(error.message, error: true);
    } on Object {
      _message('PlanIT could not delete the profile.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String value, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(value),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.session?.user;
    final enabled = !_busy && !auth.offline;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          PlanItSpacing.lg,
          PlanItSpacing.md,
          PlanItSpacing.lg,
          PlanItSpacing.xxl,
        ),
        children: <Widget>[
          if (auth.offline)
            Card(
              color: Theme.of(context).colorScheme.secondaryContainer,
              child: const ListTile(
                leading: Icon(Icons.cloud_off_outlined),
                title: Text('Offline mode'),
                subtitle: Text(
                  'Exports and profile deletion need a secure server connection.',
                ),
              ),
            ),
          if (auth.offline) const SizedBox(height: PlanItSpacing.md),
          _Section(
            title: 'Preferences',
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.currency_exchange_rounded),
                title: const Text('Base currency'),
                subtitle: Text(user?.baseCurrency ?? 'Not available'),
              ),
              ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Time zone'),
                subtitle: Text(user?.timezone ?? 'Not available'),
              ),
              const ListTile(
                leading: Icon(Icons.contrast_rounded),
                title: Text('Appearance'),
                subtitle: Text('Follows your device light or dark theme'),
              ),
            ],
          ),
          const SizedBox(height: PlanItSpacing.lg),
          _Section(
            title: 'Your data',
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined),
                title: const Text('Export transactions'),
                subtitle: const Text('CSV with exact amounts for spreadsheets'),
                trailing: const Icon(Icons.download_rounded),
                enabled: enabled,
                onTap: enabled
                    ? () => _download(
                        (token) =>
                            _api.exportCsv(token, dataType: 'transactions'),
                      )
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_outlined),
                title: const Text('Export account balances'),
                subtitle: const Text('CSV balance snapshot as of now'),
                trailing: const Icon(Icons.download_rounded),
                enabled: enabled,
                onTap: enabled
                    ? () => _download(
                        (token) => _api.exportCsv(token, dataType: 'accounts'),
                      )
                    : null,
              ),
              ListTile(
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Create portable backup'),
                subtitle: const Text(
                  'Private JSON copy without passwords, tokens, or receipt files',
                ),
                trailing: const Icon(Icons.download_rounded),
                enabled: enabled,
                onTap: enabled
                    ? () => _download((token) => _api.backup(token))
                    : null,
              ),
            ],
          ),
          const SizedBox(height: PlanItSpacing.lg),
          const _Section(
            title: 'Security',
            children: <Widget>[
              ListTile(
                leading: Icon(Icons.phonelink_lock_rounded),
                title: Text('Protected session'),
                subtitle: Text(
                  'Session keys are stored in the device security vault and removed when you sign out.',
                ),
              ),
              ListTile(
                leading: Icon(Icons.lock_outline_rounded),
                title: Text('Private media'),
                subtitle: Text(
                  'Receipts and images use short-lived private links.',
                ),
              ),
            ],
          ),
          const SizedBox(height: PlanItSpacing.lg),
          Semantics(
            container: true,
            label: 'Danger zone. Permanently delete profile and private data.',
            child: Card(
              color: Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(PlanItSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text(
                      'Danger zone',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: PlanItSpacing.xs),
                    const Text(
                      'Profile deletion permanently removes your financial data and private media. Export a backup first.',
                    ),
                    const SizedBox(height: PlanItSpacing.md),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: enabled ? _deleteProfile : null,
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: const Text('Delete profile permanently'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_busy) ...<Widget>[
            const SizedBox(height: PlanItSpacing.md),
            const LinearProgressIndicator(semanticsLabel: 'Working securely'),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          header: true,
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: PlanItSpacing.sm),
        Card(child: Column(children: children)),
      ],
    );
  }
}

class _DeleteProfileDialog extends StatefulWidget {
  const _DeleteProfileDialog();

  @override
  State<_DeleteProfileDialog> createState() => _DeleteProfileDialogState();
}

class _DeleteProfileDialogState extends State<_DeleteProfileDialog> {
  final _password = TextEditingController();
  final _confirmation = TextEditingController();

  bool get _ready =>
      _password.text.isNotEmpty &&
      _confirmation.text == 'DELETE MY PLANIT DATA';

  @override
  void dispose() {
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete profile permanently?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text(
              'This cannot be undone. Enter your password and type DELETE MY PLANIT DATA exactly.',
            ),
            const SizedBox(height: PlanItSpacing.md),
            TextField(
              controller: _password,
              obscureText: true,
              autofillHints: const <String>[AutofillHints.password],
              decoration: const InputDecoration(labelText: 'Current password'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: PlanItSpacing.sm),
            TextField(
              controller: _confirmation,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Confirmation phrase',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _ready
              ? () => Navigator.of(context).pop((
                  password: _password.text,
                  confirmation: _confirmation.text,
                ))
              : null,
          child: const Text('Delete permanently'),
        ),
      ],
    );
  }
}
