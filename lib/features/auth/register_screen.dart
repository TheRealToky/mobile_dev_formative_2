import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/constants.dart';
import '../../core/errors.dart';
import '../../core/utils/feedback.dart';
import '../../core/validators.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/password_field.dart';
import 'widgets/auth_layout.dart';

/// Account creation for ALU emails. On success Firebase signs the user in
/// and the router moves them to the Verify Email screen.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .register(
          email: _email.text,
          password: _password.text,
          displayName: _name.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        showSnack(context, friendlyError(error), isError: true);
      }
    });
    final isLoading = ref.watch(authControllerProvider).isLoading;
    final domains = allowedEmailDomains.map((d) => '@$d').join(' or ');

    return AuthLayout(
      title: 'Create your account',
      subtitle: 'Use your ALU email. We will send you a link to confirm it.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.name],
                autovalidateMode: AutovalidateMode.onUnfocus,
                validator: Validators.displayName,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),
              const SizedBox(height: Gap.lg),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autovalidateMode: AutovalidateMode.onUnfocus,
                validator: Validators.email,
                decoration: InputDecoration(
                  labelText: 'ALU email',
                  helperText: 'Ends in $domains',
                  prefixIcon: const Icon(Icons.alternate_email),
                ),
              ),
              const SizedBox(height: Gap.lg),
              PasswordField(
                controller: _password,
                label: 'Password',
                helperText: 'At least 8 characters, with a letter and a number',
                validator: Validators.newPassword,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: Gap.lg),
              PasswordField(
                controller: _confirm,
                label: 'Confirm password',
                validator: Validators.confirmPassword(() => _password.text),
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: Gap.xl),
              LoadingButton(
                label: 'Create account',
                isLoading: isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: Gap.lg),
              TextButton(
                onPressed: isLoading ? null : () => context.go(Routes.login),
                child: const Text('I already have an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
