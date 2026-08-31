import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:planit_mobile/core/auth/application/auth_controller.dart';
import 'package:planit_mobile/core/auth/domain/password_policy.dart';
import 'package:planit_mobile/core/design_system/tokens.dart';
import 'package:planit_mobile/features/auth/presentation/widgets/auth_scaffold.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _currencyController = TextEditingController(text: 'MAD');
  final _timezoneController = TextEditingController(text: 'Africa/Casablanca');
  bool _hidePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _currencyController.dispose();
    _timezoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    FocusScope.of(context).unfocus();
    await ref
        .read(authControllerProvider.notifier)
        .register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: _nameController.text.trim(),
          baseCurrency: _currencyController.text.trim().toUpperCase(),
          timezone: _timezoneController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return AuthScaffold(
      title: 'Build a trustworthy money picture',
      subtitle:
          'Choose your reporting currency and keep every account under one secure identity.',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (auth.errorMessage != null) ...<Widget>[
              AuthErrorBanner(message: auth.errorMessage!),
              const SizedBox(height: PlanItSpacing.md),
            ],
            TextFormField(
              controller: _nameController,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.name],
              decoration: const InputDecoration(
                labelText: 'Display name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) => (value?.trim().isNotEmpty ?? false)
                  ? null
                  : 'Enter your name.',
            ),
            const SizedBox(height: PlanItSpacing.md),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.email],
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline_rounded),
              ),
              validator: (value) => (value?.contains('@') ?? false)
                  ? null
                  : 'Enter a valid email address.',
            ),
            const SizedBox(height: PlanItSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: TextFormField(
                    controller: _currencyController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 3,
                    decoration: const InputDecoration(
                      labelText: 'Base currency',
                      counterText: '',
                    ),
                    validator: (value) =>
                        RegExp(r'^[A-Za-z]{3}$').hasMatch(value?.trim() ?? '')
                        ? null
                        : 'Use 3 letters.',
                  ),
                ),
                const SizedBox(width: PlanItSpacing.sm),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _timezoneController,
                    decoration: const InputDecoration(labelText: 'Timezone'),
                    validator: (value) => (value?.contains('/') ?? false)
                        ? null
                        : 'Use an IANA timezone.',
                  ),
                ),
              ],
            ),
            const SizedBox(height: PlanItSpacing.md),
            TextFormField(
              controller: _passwordController,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const <String>[AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Password',
                helperText:
                    '12+ characters with uppercase, lowercase, number, and symbol',
                helperMaxLines: 2,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: IconButton(
                  tooltip: _hidePassword ? 'Show password' : 'Hide password',
                  onPressed: () =>
                      setState(() => _hidePassword = !_hidePassword),
                  icon: Icon(
                    _hidePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
              validator: PasswordPolicy.validate,
            ),
            const SizedBox(height: PlanItSpacing.xs),
            _PasswordChecklist(value: _passwordController.text),
            const SizedBox(height: PlanItSpacing.md),
            TextFormField(
              controller: _confirmController,
              obscureText: _hidePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Confirm password',
                prefixIcon: Icon(Icons.verified_user_outlined),
              ),
              validator: (value) => value == _passwordController.text
                  ? null
                  : 'Passwords do not match.',
            ),
            const SizedBox(height: PlanItSpacing.lg),
            FilledButton(
              onPressed: auth.busy ? null : _submit,
              child: auth.busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create account'),
            ),
            const SizedBox(height: PlanItSpacing.md),
            TextButton(
              onPressed: auth.busy ? null : () => context.go('/sign-in'),
              child: const Text('Already have an account? Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PasswordChecklist extends StatelessWidget {
  const _PasswordChecklist({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final requirements = <(String, bool)>[
      ('12+ characters', PasswordPolicy.hasMinimumLength(value)),
      ('Uppercase', PasswordPolicy.hasUppercase(value)),
      ('Lowercase', PasswordPolicy.hasLowercase(value)),
      ('Number', PasswordPolicy.hasNumber(value)),
      ('Symbol', PasswordPolicy.hasSymbol(value)),
    ];
    return Wrap(
      spacing: PlanItSpacing.xs,
      runSpacing: PlanItSpacing.xxs,
      children: requirements
          .map(
            (requirement) => Chip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                requirement.$2
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: requirement.$2
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outline,
              ),
              label: Text(requirement.$1),
            ),
          )
          .toList(growable: false),
    );
  }
}
