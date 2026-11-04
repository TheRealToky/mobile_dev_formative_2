import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../core/errors.dart';
import '../../core/utils/feedback.dart';
import '../../core/validators.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/loading_button.dart';
import '../../widgets/password_field.dart';
import 'widgets/auth_layout.dart';

/// Email/password login. Navigation after success is handled by the router
/// redirect (verify email, or the feed), not by this screen.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailKey = GlobalKey<FormFieldState<String>>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(authControllerProvider.notifier)
        .signIn(email: _email.text, password: _password.text);
  }

  Future<void> _resetPassword() async {
    if (!(_emailKey.currentState?.validate() ?? false)) return;
    final sent = await ref
        .read(authControllerProvider.notifier)
        .sendPasswordReset(_email.text);
    if (sent && mounted) {
      showSnack(context, 'Password reset email sent to ${_email.text.trim()}.');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        showSnack(context, friendlyError(error), isError: true);
      }
    });
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return AuthLayout(
      title: 'Log in',
      subtitle: 'Report campus issues and follow them until they are fixed.',
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: _emailKey,
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autovalidateMode: AutovalidateMode.onUnfocus,
                validator: Validators.email,
                decoration: const InputDecoration(
                  labelText: 'ALU email',
                  prefixIcon: Icon(Icons.alternate_email),
                ),
              ),
              const SizedBox(height: Gap.lg),
              PasswordField(
                controller: _password,
                label: 'Password',
                validator: Validators.loginPassword,
                onFieldSubmitted: (_) => _submit(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: isLoading ? null : _resetPassword,
                  child: const Text('Forgot password?'),
                ),
              ),
              const SizedBox(height: Gap.sm),
              LoadingButton(
                label: 'Log in',
                isLoading: isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: Gap.lg),
              OutlinedButton(
                onPressed: isLoading ? null : () => context.go(Routes.register),
                child: const Text('Create an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
