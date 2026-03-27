import 'package:flutter/material.dart';
import '../core/theme/text_styles.dart';
import 'loading_indicator.dart';

enum ButtonType { primary, secondary, outlined, text }

enum ButtonSize { small, medium, large }

class CustomButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final ButtonType type;
  final ButtonSize size;
  final IconData? icon;
  final bool isLoading;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? textColor;
  final double? borderRadius;

  const CustomButton({
    super.key,
    required this.text,
    this.onPressed,
    this.type = ButtonType.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.backgroundColor,
    this.textColor,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null || isLoading;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // Get button padding based on size
    EdgeInsets getPadding() {
      switch (size) {
        case ButtonSize.small:
          return const EdgeInsets.symmetric(horizontal: 16, vertical: 10);
        case ButtonSize.medium:
          return const EdgeInsets.symmetric(horizontal: 24, vertical: 14);
        case ButtonSize.large:
          return const EdgeInsets.symmetric(horizontal: 32, vertical: 18);
      }
    }

    // Get text style based on size
    TextStyle getTextStyle() {
      final baseStyle = size == ButtonSize.small
          ? AppTextStyles.buttonSmall
          : AppTextStyles.button;
      return baseStyle.copyWith(
        color: textColor ??
            (type == ButtonType.outlined || type == ButtonType.text
                ? scheme.primary
                : scheme.onPrimary),
      );
    }

    Widget buildButtonContent() {
      if (isLoading) {
        return SizedBox(
          height: 20,
          width: 20,
          child: CustomLoadingIndicator(
            size: 16,
            color:
                type == ButtonType.primary ? scheme.onPrimary : scheme.primary,
          ),
        );
      }

      if (icon != null) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: size == ButtonSize.small ? 18 : 20),
            const SizedBox(width: 8),
            Text(text, style: getTextStyle()),
          ],
        );
      }

      return Text(text, style: getTextStyle());
    }

    switch (type) {
      case ButtonType.primary:
        return SizedBox(
          width: isFullWidth ? double.infinity : null,
          child: ElevatedButton(
            onPressed: isDisabled ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor ?? scheme.primary,
              foregroundColor: textColor ?? scheme.onPrimary,
              padding: getPadding(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius ?? 12),
              ),
              elevation: 0,
              disabledBackgroundColor: (backgroundColor ?? scheme.primary)
                  .withOpacity(0.45),
            ),
            child: buildButtonContent(),
          ),
        );

      case ButtonType.secondary:
        return SizedBox(
          width: isFullWidth ? double.infinity : null,
          child: ElevatedButton(
            onPressed: isDisabled ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: backgroundColor ?? scheme.secondary,
              foregroundColor: textColor ?? scheme.onSecondary,
              padding: getPadding(),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius ?? 12),
              ),
              elevation: 0,
              disabledBackgroundColor:
                  (backgroundColor ?? scheme.secondary).withOpacity(0.45),
            ),
            child: buildButtonContent(),
          ),
        );

      case ButtonType.outlined:
        return SizedBox(
          width: isFullWidth ? double.infinity : null,
          child: OutlinedButton(
            onPressed: isDisabled ? null : onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: textColor ?? scheme.primary,
              padding: getPadding(),
              side: BorderSide(
                color: backgroundColor ?? scheme.primary.withOpacity(0.36),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius ?? 12),
              ),
            ),
            child: buildButtonContent(),
          ),
        );

      case ButtonType.text:
        return TextButton(
          onPressed: isDisabled ? null : onPressed,
          style: TextButton.styleFrom(
            foregroundColor: textColor ?? scheme.primary,
            padding: getPadding(),
          ),
          child: buildButtonContent(),
        );
    }
  }
}

