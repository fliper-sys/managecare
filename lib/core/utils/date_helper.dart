import 'package:intl/intl.dart';

/// Helper class for date operations
class DateHelper {
  static String formatDate(DateTime date, [String format = 'dd/MM/yyyy']) {
    try {
      return DateFormat(format).format(date);
    } catch (e) {
      return date.toString();
    }
  }

  static String formatDateTime(DateTime dateTime) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    } catch (e) {
      return dateTime.toString();
    }
  }

  static String timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).toStringAsFixed(0)} years ago';
    }
    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).toStringAsFixed(0)} months ago';
    }
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    }
    if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    }
    if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    }
    return 'Just now';
  }

  static DateTime startOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime endOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }

  static bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

