import 'package:flutter/material.dart';

/// Minimal floating snackbar style used across the app.
class AppSnackBar {
  AppSnackBar._();

  static void showInfo(BuildContext context, String message) {
    _show(context, message, icon: Icons.info_outline_rounded);
  }

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, icon: Icons.check_circle_outline_rounded);
  }

  static void showError(BuildContext context, String message) {
    _show(context, message, icon: Icons.error_outline_rounded, isError: true);
  }

  static void _show(
    BuildContext context,
    String message, {
    required IconData icon,
    bool isError = false,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final cs = Theme.of(context).colorScheme;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: const Duration(seconds: 2),
          backgroundColor: isError ? cs.errorContainer : cs.inverseSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isError ? cs.onErrorContainer : cs.onInverseSurface,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isError ? cs.onErrorContainer : cs.onInverseSurface,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
