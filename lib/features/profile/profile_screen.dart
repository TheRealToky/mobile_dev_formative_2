import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme.dart';
import '../../providers/auth_providers.dart';

/// Signed-in user's name, email, role and logout.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final busy = ref.watch(authControllerProvider).isLoading;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(Gap.lg),
        children: [
          if (profile != null) ...[
            Text(profile.displayName, style: textTheme.headlineSmall),
            const SizedBox(height: Gap.xs),
            Text(profile.email, style: textTheme.bodyLarge),
            const SizedBox(height: Gap.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Chip(label: Text(profile.role.label)),
            ),
          ],
          const SizedBox(height: Gap.xl),
          OutlinedButton.icon(
            onPressed: busy
                ? null
                : () => ref.read(authControllerProvider.notifier).signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}
