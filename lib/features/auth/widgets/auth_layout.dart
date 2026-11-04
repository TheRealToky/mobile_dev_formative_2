import 'package:flutter/material.dart';

import '../../../app/theme.dart';

/// Shared frame for the auth screens: app mark, title, one-line subtitle and
/// the form, centred and width-limited so it reads well in landscape and on
/// tablets.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.icon = Icons.handyman_outlined,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: Gap.lg,
              vertical: Gap.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(Radii.card),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.md),
                      child: Icon(
                        icon,
                        size: 32,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: Gap.xl),
                  Text(title, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: Gap.sm),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: Gap.xl),
                  child,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
