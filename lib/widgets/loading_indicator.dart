import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../core/theme/colors.dart';

class CustomLoadingIndicator extends StatelessWidget {
  final double? size;
  final Color? color;
  final double? strokeWidth;
  final String? message;

  const CustomLoadingIndicator({
    super.key,
    this.size,
    this.color,
    this.strokeWidth,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size ?? 64,
          height: size ?? 64,
          child: Lottie.asset(
            'assets/lottie/loop.json',
            repeat: true,
            fit: BoxFit.contain,
          ),
        ),
        if (message != null) ...[
          const SizedBox(height: 16),
          Text(
            message!,
            style: TextStyle(
              fontSize: 14,
              color: color ?? AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

class LoadingOverlay extends StatelessWidget {
  final bool isLoading;
  final Widget child;
  final String? message;

  const LoadingOverlay({
    super.key,
    required this.isLoading,
    required this.child,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: CustomLoadingIndicator(
                    message: message,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Simple LoadingIndicator wrapper for backward compatibility
class LoadingIndicator extends StatelessWidget {
  final double? size;
  final Color? color;
  final double? strokeWidth;
  final String? message;

  const LoadingIndicator(
      {super.key, this.size, this.color, this.strokeWidth, this.message});

  @override
  Widget build(BuildContext context) {
    return CustomLoadingIndicator(
        size: size, color: color, strokeWidth: strokeWidth, message: message);
  }
}

