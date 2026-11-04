import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../core/errors.dart';
import '../../providers/auth_providers.dart';

/// Shown until the first auth event and the profile document have resolved,
/// so the router never flashes the wrong screen. If the profile fails to
/// load, it offers a retry and a way out instead of spinning forever.
class SplashScreen extends ConsumerWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: switch (session) {
              SessionError(:final error) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_outlined,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: Gap.lg),
                  Text(
                    'Could not load your profile',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(friendlyError(error), textAlign: TextAlign.center),
                  const SizedBox(height: Gap.xl),
                  FilledButton(
                    onPressed: () => ref.invalidate(currentUserProfileProvider),
                    child: const Text('Try again'),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                    child: const Text('Log out'),
                  ),
                ],
              ),
              _ => Semantics(
                label: 'Loading',
                child: const CircularProgressIndicator(),
              ),
            },
          ),
        ),
      ),
    );
  }
}
