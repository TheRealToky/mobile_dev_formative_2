import 'package:flutter/material.dart';

/// Shows a floating snackbar, replacing any visible one.
void showSnack(BuildContext context, String message, {bool isError = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? scheme.error : null,
        showCloseIcon: isError,
        closeIconColor: isError ? scheme.onError : null,
      ),
    );
}
