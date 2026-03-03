import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

/// Safely attempt to read a provider without throwing if it's not available yet.
extension SafeProviderAccess on BuildContext {
  /// Returns an instance of [T] if available, otherwise returns null.
  T? tryRead<T>() {
    try {
      return Provider.of<T>(this, listen: false);
    } catch (_) {
      return null;
    }
  }

  /// Returns an instance of [T] if available in the widget tree, otherwise null.
  T? tryWatch<T>() {
    try {
      return Provider.of<T>(this);
    } catch (_) {
      return null;
    }
  }
}
