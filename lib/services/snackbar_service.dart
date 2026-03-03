import 'package:flutter/material.dart';

// Global scaffold messenger key for app-wide snackbars (safe across navigation)
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class SnackBarService {
  /// Show a SnackBar using the global scaffold messenger if available.
  /// Falls back to the provided `context` if necessary.
  static void showSnackBar({
    String? message,
    SnackBar? snackBar,
    BuildContext? context,
    Duration? duration,
  }) {
    final messenger = scaffoldMessengerKey.currentState;

    if (snackBar != null) {
      if (messenger != null) {
        messenger.showSnackBar(snackBar);
        return;
      }
      if (context != null && ScaffoldMessenger.maybeOf(context) != null) {
        ScaffoldMessenger.of(context).showSnackBar(snackBar);
        return;
      }
      print('[SnackBarService] No messenger available to show SnackBar');
      return;
    }

    final sb = SnackBar(
      content: Text(message ?? ''),
      duration: duration ?? const Duration(seconds: 2),
    );

    if (messenger != null) {
      messenger.showSnackBar(sb);
      return;
    }

    if (context != null && ScaffoldMessenger.maybeOf(context) != null) {
      ScaffoldMessenger.of(context).showSnackBar(sb);
      return;
    }

    // If no messenger is available, log the message as a fallback
    print('[SnackBarService] Snackbar: ${message ?? '(empty)'}');
  }

  static void showError(BuildContext? context, String message,
      {Duration? duration}) {
    showSnackBar(
      snackBar: SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 3),
        backgroundColor: Colors.red,
      ),
      context: context,
    );
  }
}
