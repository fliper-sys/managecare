import 'package:flutter/material.dart';
import 'animated_lottie.dart';

Future<T?> showLottieDialog<T>(
  BuildContext context, {
  required String asset,
  String? title,
  String? message,
  bool isSuccess = true,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedLottie(
                  asset: asset,
                  width: 140,
                  height: 140,
                  repeat: false,
                ),
                if (title != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
                if (message != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Future<T?> showSuccessLottieDialog<T>(
  BuildContext context, {
  String? title,
  String? message,
  bool barrierDismissible = true,
}) {
  return showLottieDialog<T>(
    context,
    asset: 'assets/lottie/success.json',
    title: title ?? 'Success',
    message: message,
    isSuccess: true,
    barrierDismissible: barrierDismissible,
  );
}

Future<T?> showErrorLottieDialog<T>(
  BuildContext context, {
  String? title,
  String? message,
  bool barrierDismissible = true,
}) {
  return showLottieDialog<T>(
    context,
    asset: 'assets/lottie/error.json',
    title: title ?? 'Error',
    message: message,
    isSuccess: false,
    barrierDismissible: barrierDismissible,
  );
}

Future<T?> showHintLottieDialog<T>(
  BuildContext context, {
  String? title,
  String? message,
  bool barrierDismissible = true,
}) {
  return showLottieDialog<T>(
    context,
    asset: 'assets/lottie/onboard2.json',
    title: title,
    message: message,
    isSuccess: true,
    barrierDismissible: barrierDismissible,
  );
}

/// Runs [action] and if it throws, shows an error Lottie dialog with
/// the thrown error message. Returns the action result or `null` on error.
Future<T?> runWithLottieErrorHandling<T>(
  BuildContext context,
  Future<T> Function() action, {
  String? errorTitle,
  String? errorMessage,
}) async {
  try {
    return await action();
  } catch (e) {
    await showErrorLottieDialog(
      context,
      title: errorTitle ?? 'Error',
      message: errorMessage ?? e.toString(),
    );
    return null;
  }
}

