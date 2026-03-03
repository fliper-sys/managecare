/// Collection extension methods
extension ListExtensions<T> on List<T> {
  /// Returns the first element that satisfies the given test, or null if not found
  T? firstWhereOrNull(bool Function(T) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}

