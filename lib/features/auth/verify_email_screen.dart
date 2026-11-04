import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/errors.dart';
import '../../core/utils/feedback.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/loading_button.dart';
import 'widgets/auth_layout.dart';

/// Holds signed-in but unverified users until they open the email link.
///
/// Firebase does not push `emailVerified` changes, so this screen reloads the
/// user every few seconds and whenever the app returns to the foreground
/// (the user usually leaves to open their mail app). Once verified, the
/// router redirect moves on automatically.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  /// How often to poll while the screen is visible.
  static const pollInterval = Duration(seconds: 5);

  /// Wait between resend requests, to respect Firebase rate limits.
  static const resendCooldown = Duration(seconds: 60);

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen>
    with WidgetsBindingObserver {
  Timer? _poll;
  Timer? _cooldownTicker;
  int _cooldownLeft = 0;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _poll = Timer.periodic(VerifyEmailScreen.pollInterval, (_) => _check());
    // Registration just sent an email; start the cooldown so the first
    // resend is not immediate.
    _startCooldown();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _cooldownTicker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check({bool userInitiated = false}) async {
    if (_checking) return;
    _checking = true;
    if (userInitiated) setState(() {});
    final verified = await ref
        .read(authControllerProvider.notifier)
        .checkEmailVerified();
    _checking = false;
    if (!mounted) return;
    if (userInitiated) {
      setState(() {});
      if (!verified) {
        showSnack(context, 'Not verified yet. Open the link in the email.');
      }
    }
  }

  void _startCooldown() {
    _cooldownTicker?.cancel();
    setState(() => _cooldownLeft = VerifyEmailScreen.resendCooldown.inSeconds);
    _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldownLeft--);
      if (_cooldownLeft <= 0) t.cancel();
    });
  }

  Future<void> _resend() async {
    final sent = await ref
        .read(authControllerProvider.notifier)
        .resendVerification();
    if (!mounted || !sent) return;
    showSnack(context, 'Verification email sent.');
    _startCooldown();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider, (_, next) {
      if (next case AsyncError(:final error)) {
        showSnack(context, friendlyError(error), isError: true);
      }
    });
    final session = ref.watch(sessionProvider);
    final email = session is SessionUnverified ? session.email : 'your inbox';
    final busy = ref.watch(authControllerProvider).isLoading;
    final textTheme = Theme.of(context).textTheme;

    return AuthLayout(
      icon: Icons.mark_email_unread_outlined,
      title: 'Check your email',
      subtitle:
          'We sent a link to $email. Open it, then come back here. '
          'This screen moves on by itself once you are verified.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LoadingButton(
            label: 'I have verified my email',
            isLoading: _checking,
            onPressed: () => _check(userInitiated: true),
          ),
          const SizedBox(height: Gap.md),
          OutlinedButton.icon(
            onPressed: busy || _cooldownLeft > 0 ? null : _resend,
            icon: const Icon(Icons.refresh),
            label: Text(
              _cooldownLeft > 0
                  ? 'Resend email in ${_cooldownLeft}s'
                  : 'Resend email',
            ),
          ),
          const SizedBox(height: Gap.xl),
          Text(
            'No email? Check your spam folder, or make sure the address '
            'above is correct.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: Gap.sm),
          TextButton(
            onPressed: busy
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
            child: const Text('Use a different account'),
          ),
        ],
      ),
    );
  }
}
