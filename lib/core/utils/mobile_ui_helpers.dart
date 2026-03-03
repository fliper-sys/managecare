import 'package:flutter/material.dart';

/// Mobile-optimized bottom sheet handler
class MobileBottomSheet {
  static Future<T?> show<T>(
    BuildContext context, {
    required Widget Function(BuildContext) builder,
    bool isScrollControlled = true,
    bool isDismissible = true,
    Color? barrierColor,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      barrierColor: barrierColor ?? Colors.black.withOpacity(0.3),
      useSafeArea: true,
      builder: builder,
    );
  }

  static Future<T?> showHalfSheet<T>(
    BuildContext context, {
    required Widget Function(BuildContext) builder,
    bool isDismissible = true,
  }) {
    return show<T>(
      context,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.25,
        maxChildSize: 0.9,
        builder: (context, scrollController) => builder(context),
      ),
      isDismissible: isDismissible,
      isScrollControlled: true,
    );
  }

  static Future<T?> showActionSheet<T>(
    BuildContext context, {
    required List<ActionSheetItem<T>> items,
    String? title,
    Widget Function(BuildContext)? headerBuilder,
  }) {
    return show<T>(
      context,
      builder: (context) => ActionSheetWidget<T>(
        items: items,
        title: title,
        headerBuilder: headerBuilder,
      ),
      isDismissible: true,
    );
  }
}

/// Action sheet item
class ActionSheetItem<T> {
  final String label;
  final IconData? icon;
  final VoidCallback onTap;
  final Color? color;
  final bool isDestructive;

  ActionSheetItem({
    required this.label,
    this.icon,
    required this.onTap,
    this.color,
    this.isDestructive = false,
  });
}

/// Action sheet widget
class ActionSheetWidget<T> extends StatelessWidget {
  final List<ActionSheetItem<T>> items;
  final String? title;
  final Widget Function(BuildContext)? headerBuilder;

  const ActionSheetWidget({
    super.key,
    required this.items,
    this.title,
    this.headerBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (headerBuilder != null)
          headerBuilder!(context)
        else if (title != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title!,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ...items.map((item) => _buildActionItem(context, item)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                foregroundColor: Colors.black87,
              ),
              child: const Text('Cancel'),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildActionItem(BuildContext context, ActionSheetItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            item.onTap();
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: item.isDestructive
                  ? Colors.red.withOpacity(0.1)
                  : Colors.grey.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                if (item.icon != null) ...[
                  Icon(
                    item.icon,
                    color: item.isDestructive ? Colors.red : item.color,
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    item.label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: item.isDestructive ? Colors.red : item.color,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Mobile-optimized dialog
class MobileDialog {
  static Future<T?> show<T>(
    BuildContext context, {
    required String title,
    required String message,
    List<DialogAction<T>>? actions,
    bool dismissible = true,
  }) {
    return showDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      useSafeArea: true,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: actions
            ?.map((action) => TextButton(
                  onPressed: () {
                    Navigator.pop(context, action.value);
                    action.onPressed?.call();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: action.isDestructive ? Colors.red : null,
                  ),
                  child: Text(action.label),
                ))
            .toList(),
      ),
    );
  }

  static Future<bool?> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'OK',
    String cancelLabel = 'Cancel',
  }) {
    return show<bool>(
      context,
      title: title,
      message: message,
      actions: [
        DialogAction<bool>(
          label: cancelLabel,
          value: false,
        ),
        DialogAction<bool>(
          label: confirmLabel,
          value: true,
        ),
      ],
    );
  }
}

class DialogAction<T> {
  final String label;
  final T? value;
  final VoidCallback? onPressed;
  final bool isDestructive;

  DialogAction({
    required this.label,
    this.value,
    this.onPressed,
    this.isDestructive = false,
  });
}

/// Mobile-optimized snackbar
class MobileSnackBar {
  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
    SnackBarAction? action,
    SnackBarBehavior behavior = SnackBarBehavior.floating,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration,
        behavior: behavior,
        action: action,
        margin: behavior == SnackBarBehavior.floating
            ? const EdgeInsets.all(12)
            : EdgeInsets.zero,
        shape: behavior == SnackBarBehavior.floating
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))
            : null,
      ),
    );
  }

  static void showSuccess(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 2),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static void showError(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static void showWarning(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

/// Mobile-optimized loading dialog
class MobileLoadingDialog {
  static void show(
    BuildContext context, {
    String message = 'Loading...',
    bool dismissible = false,
  }) {
    showDialog(
      context: context,
      barrierDismissible: dismissible,
      useSafeArea: true,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(message),
          ],
        ),
      ),
    );
  }

  static void dismiss(BuildContext context) {
    Navigator.of(context).pop();
  }
}

