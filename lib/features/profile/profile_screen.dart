import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../app/theme.dart';
import '../../data/models/app_user.dart';
import '../../data/models/incident.dart';
import '../../providers/auth_providers.dart';
import '../../providers/incident_providers.dart';
import '../../providers/theme_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/error_view.dart';
import '../../widgets/incident_card.dart';

/// The signed-in user: who they are, their role, their own reports
/// (students only; staff do not file reports), appearance and log out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentUserProfileProvider).value;
    final isStaff = profile?.isStaff ?? false;
    final textTheme = Theme.of(context).textTheme;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: Gap.xl, bottom: Gap.sm),
      child: Text(text, style: textTheme.titleMedium),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kMaxContentWidth),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                Gap.lg,
                Gap.lg,
                Gap.lg,
                Gap.xxl,
              ),
              children: [
                if (profile != null) _Header(profile: profile),
                if (!isStaff) ...[
                  heading('My reports'),
                  ..._myReports(context, ref, ref.watch(myIncidentsProvider)),
                ],
                heading('Appearance'),
                const _ThemeModePicker(),
                const SizedBox(height: Gap.xxl),
                const _LogoutButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _myReports(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Incident>> mine,
  ) {
    if (mine.hasError && !mine.isLoading) {
      return [
        ErrorView(
          error: mine.error!,
          title: 'Could not load your reports',
          onRetry: () => ref.invalidate(myIncidentsProvider),
        ),
      ];
    }
    final list = mine.value;
    if (list == null) {
      return const [IncidentCardSkeleton(), SizedBox(height: Gap.sm)];
    }
    if (list.isEmpty) {
      return [
        EmptyState(
          icon: Icons.outbox_outlined,
          message: 'You have not reported anything yet.',
          actionLabel: 'Report an issue',
          onAction: () => context.go(Routes.report),
        ),
      ];
    }
    final open = list.where((i) => i.status.isOpen).length;
    return [
      Text(
        '${list.length} ${list.length == 1 ? 'report' : 'reports'}, '
        '$open still open',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const SizedBox(height: Gap.sm),
      for (final incident in list) ...[
        IncidentCard(
          incident: incident,
          onTap: () => context.push(Routes.incident(incident.id)),
        ),
        const SizedBox(height: Gap.sm),
      ],
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile});

  final AppUser profile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final initials = profile.displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase())
        .join();

    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          child: Text(
            initials.isEmpty ? '?' : initials,
            style: theme.textTheme.titleLarge?.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
        ),
        const SizedBox(width: Gap.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(profile.displayName, style: theme.textTheme.headlineSmall),
              Text(
                profile.email,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: Gap.sm),
              RoleBadge(role: profile.role),
            ],
          ),
        ),
      ],
    );
  }
}

/// Role shown as icon + text. Staff get the primary colour so it stands out
/// on shared devices during demos.
class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isStaff = role == UserRole.staff;
    final fg = isStaff ? scheme.onPrimary : scheme.onSecondaryContainer;
    return Semantics(
      label: 'Role: ${role.label}',
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isStaff ? scheme.primary : scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(Radii.chip),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Gap.sm,
            vertical: Gap.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isStaff ? Icons.badge_outlined : Icons.school_outlined,
                size: 16,
                color: fg,
              ),
              const SizedBox(width: Gap.xs),
              Text(
                role.label,
                style: Theme.of(context).textTheme.labelMedium
                    ?.copyWith(color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeModePicker extends ConsumerWidget {
  const _ThemeModePicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment(
          value: ThemeMode.system,
          icon: Icon(Icons.brightness_auto_outlined),
          label: Text('System'),
        ),
        ButtonSegment(
          value: ThemeMode.light,
          icon: Icon(Icons.light_mode_outlined),
          label: Text('Light'),
        ),
        ButtonSegment(
          value: ThemeMode.dark,
          icon: Icon(Icons.dark_mode_outlined),
          label: Text('Dark'),
        ),
      ],
      selected: {mode},
      showSelectedIcon: false,
      onSelectionChanged: (s) =>
          ref.read(themeModeProvider.notifier).set(s.single),
    );
  }
}

class _LogoutButton extends ConsumerWidget {
  const _LogoutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final busy = ref.watch(authControllerProvider).isLoading;
    return OutlinedButton.icon(
      onPressed: busy
          ? null
          : () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Log out?'),
                  content: const Text(
                    'You will need your ALU email and password to sign in '
                    'again.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Stay signed in'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Log out'),
                    ),
                  ],
                ),
              );
              if (ok == true) {
                await ref.read(authControllerProvider.notifier).signOut();
              }
            },
      icon: const Icon(Icons.logout),
      label: const Text('Log out'),
    );
  }
}
