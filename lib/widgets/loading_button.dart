import 'package:flutter/material.dart';

/// Full-width primary button that shows a spinner and ignores taps while
/// [isLoading] is true, which prevents duplicate submissions.
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final spinner = SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2.5,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
    );
    final child = isLoading
        ? Semantics(label: '$label, in progress', child: spinner)
        : Text(label);

    return SizedBox(
      width: double.infinity,
      child: icon == null || isLoading
          ? FilledButton(onPressed: isLoading ? null : onPressed, child: child)
          : FilledButton.icon(
              onPressed: onPressed,
              icon: Icon(icon),
              label: child,
            ),
    );
  }
}
