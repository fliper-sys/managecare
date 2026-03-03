import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/theme/text_styles.dart';
import 'custom_button.dart';

class CustomErrorWidget extends StatelessWidget {
  final String message;
  final String? title;
  final IconData? icon;
  final VoidCallback? onRetry;
  final ErrorType errorType;

  const CustomErrorWidget({
    super.key,
    required this.message,
    this.title,
    this.icon,
    this.onRetry,
    this.errorType = ErrorType.general,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error Icon Container
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: _getIconBackgroundColor(),
                  borderRadius: BorderRadius.circular(50),
                  boxShadow: [
                    BoxShadow(
                      color: _getErrorColor().withOpacity(0.2),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    icon ?? _getIconForErrorType(),
                    size: 52,
                    color: _getErrorColor(),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Title
              if (title != null) ...[
                Text(
                  title!,
                  style: AppTextStyles.heading3.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ] else ...[
                Text(
                  _getDefaultTitle(),
                  style: AppTextStyles.heading3.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
              ],

              // Message
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  message,
                  style: AppTextStyles.body1.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Error Code (if available)
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _getErrorColor().withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getErrorColor().withOpacity(0.2),
                    width: 1.5,
                  ),
                ),
                child: Text(
                  _getErrorCode(),
                  style: AppTextStyles.caption.copyWith(
                    color: _getErrorColor(),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              // Action Buttons
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: Column(
                  children: [
                    if (onRetry != null) ...[
                      CustomButton(
                        text: 'Try Again',
                        onPressed: onRetry,
                        isFullWidth: true,
                        icon: Icons.refresh_rounded,
                      ),
                      const SizedBox(height: 12),
                    ],
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: BorderSide(
                          color: _getErrorColor().withOpacity(0.3),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Go Back',
                        style: AppTextStyles.subtitle2.copyWith(
                          color: _getErrorColor(),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getErrorColor() {
    switch (errorType) {
      case ErrorType.network:
        return Colors.orange;
      case ErrorType.offline:
        return Colors.grey;
      case ErrorType.timeout:
        return Colors.amber;
      case ErrorType.unauthorized:
        return Colors.red;
      case ErrorType.notFound:
        return Colors.indigo;
      case ErrorType.general:
        return AppColors.error;
    }
  }

  Color _getIconBackgroundColor() {
    return _getErrorColor().withOpacity(0.1);
  }

  IconData _getIconForErrorType() {
    switch (errorType) {
      case ErrorType.network:
        return Icons.signal_cellular_nodata_rounded;
      case ErrorType.offline:
        return Icons.cloud_off_rounded;
      case ErrorType.timeout:
        return Icons.schedule_rounded;
      case ErrorType.unauthorized:
        return Icons.lock_outline_rounded;
      case ErrorType.notFound:
        return Icons.find_in_page_rounded;
      case ErrorType.general:
        return Icons.error_outline_rounded;
    }
  }

  String _getDefaultTitle() {
    switch (errorType) {
      case ErrorType.network:
        return 'Connection Lost';
      case ErrorType.offline:
        return 'You\'re Offline';
      case ErrorType.timeout:
        return 'Request Timeout';
      case ErrorType.unauthorized:
        return 'Access Denied';
      case ErrorType.notFound:
        return 'Not Found';
      case ErrorType.general:
        return 'Something Went Wrong';
    }
  }

  String _getErrorCode() {
    switch (errorType) {
      case ErrorType.network:
        return 'ERROR_NETWORK';
      case ErrorType.offline:
        return 'ERROR_OFFLINE';
      case ErrorType.timeout:
        return 'ERROR_TIMEOUT';
      case ErrorType.unauthorized:
        return 'ERROR_401_UNAUTHORIZED';
      case ErrorType.notFound:
        return 'ERROR_404_NOT_FOUND';
      case ErrorType.general:
        return 'ERROR_GENERAL';
    }
  }
}

enum ErrorType {
  general,
  network,
  offline,
  timeout,
  unauthorized,
  notFound,
}

