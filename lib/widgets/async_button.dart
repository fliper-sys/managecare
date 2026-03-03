import 'dart:async';

import 'package:flutter/material.dart';
import 'custom_button.dart';

/// A button that runs an async callback and prevents multiple concurrent taps.
///
/// Usage: replace `ElevatedButton(onPressed: () async { ... })` with
/// `AsyncButton(onPressed: () async { ... }, child: Text('Confirm'))`.
class AsyncButton extends StatefulWidget {
  final FutureOr<void> Function()? onPressed;
  final Widget child;
  final ButtonStyle? style;
  final Key? buttonKey;

  const AsyncButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.style,
    this.buttonKey,
  });

  @override
  State<AsyncButton> createState() => _AsyncButtonState();
}

class _AsyncButtonState extends State<AsyncButton> {
  bool _loading = false;

  Future<void> _handlePress() async {
    if (_loading) return;
    final cb = widget.onPressed;
    if (cb == null) return;

    setState(() => _loading = true);
    try {
      await cb();
    } catch (e) {
      rethrow;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || _loading;
    return ElevatedButton(
      key: widget.buttonKey,
      style: widget.style,
      onPressed: isDisabled ? null : _handlePress,
      child: _loading
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Theme.of(context).colorScheme.onPrimary)),
                ),
                const SizedBox(width: 8),
                DefaultTextStyle.merge(style: const TextStyle(fontSize: 14), child: widget.child),
              ],
            )
          : widget.child,
    );
  }
}

/// Async wrapper for the project's `CustomButton` that manages its own loading state.
class AsyncCustomButton extends StatefulWidget {
  final Future<void> Function()? onPressed;
  final String text;
  final ButtonType type;
  final ButtonSize size;
  final IconData? icon;
  final bool isFullWidth;
  final Color? backgroundColor;
  final Color? textColor;
  final double? borderRadius;
  final Key? buttonKey;

  const AsyncCustomButton({
    super.key,
    required this.onPressed,
    required this.text,
    this.type = ButtonType.primary,
    this.size = ButtonSize.medium,
    this.icon,
    this.isFullWidth = true,
    this.backgroundColor,
    this.textColor,
    this.borderRadius,
    this.buttonKey,
  });

  @override
  State<AsyncCustomButton> createState() => _AsyncCustomButtonState();
}

class _AsyncCustomButtonState extends State<AsyncCustomButton> {
  bool _loading = false;

  Future<void> _handle() async {
    if (_loading) return;
    final cb = widget.onPressed;
    if (cb == null) return;
    setState(() => _loading = true);
    try {
      await cb();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomButton(
      text: widget.text,
      onPressed: _loading ? null : () => _handle(),
      type: widget.type,
      size: widget.size,
      icon: widget.icon,
      isLoading: _loading,
      isFullWidth: widget.isFullWidth,
      backgroundColor: widget.backgroundColor,
      textColor: widget.textColor,
      borderRadius: widget.borderRadius,
    );
  }
}

