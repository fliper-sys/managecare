import 'package:flutter/material.dart';
import 'notification_service.dart';

/// Business event notification manager
/// Centralized place to trigger notifications for all business events
class BusinessNotificationManager {
  static final BusinessNotificationManager _instance =
      BusinessNotificationManager._internal();

  final NotificationService _notificationService = NotificationService.instance;
  int _notificationCounter = 0;

  factory BusinessNotificationManager() {
    return _instance;
  }

  BusinessNotificationManager._internal();

  static BusinessNotificationManager get instance => _instance;

  /// ===== SALES NOTIFICATIONS =====

  /// Notify when a sale is completed
  Future<void> notifySaleCompleted({
    required String businessId,
    required String customerName,
    required double amount,
    required String paymentMethod,
  }) async {
    try {
      const title = '✅ Sale Completed';
      final body =
          '$customerName - ${amount.toStringAsFixed(2)} via $paymentMethod';
      await _notificationService.sendNotification(title, body,
          id: _getNotificationId('sale', businessId));
    } catch (e) {
      debugPrint('Error notifying sale completed: $e');
    }
  }

  /// Notify when a large sale occurs (threshold based)
  Future<void> notifyLargeSale({
    required String businessId,
    required String customerName,
    required double amount,
  }) async {
    try {
      const title = '💰 Large Sale Alert';
      final body = '$customerName purchased ${amount.toStringAsFixed(2)}';
      await _notificationService.sendNotification(title, body,
          id: _getNotificationId('large_sale', businessId));
    } catch (e) {
      debugPrint('Error notifying large sale: $e');
    }
  }

  /// ===== INVENTORY NOTIFICATIONS =====

  /// Notify when stock is low
  Future<void> notifyLowStock({
    required String businessId,
    required String itemName,
    required int currentStock,
    required int reorderPoint,
  }) async {
    try {
      const title = '⚠️ Low Stock Alert';
      final body = '$itemName: $currentStock left (Min: $reorderPoint)';
      await _notificationService.sendNotification(title, body,
          id: _getNotificationId('low_stock', businessId));
    } catch (e) {
      debugPrint('Error notifying low stock: $e');
    }
  }

  /// Notify when item is out of stock
  Future<void> notifyOutOfStock({
    required String businessId,
    required String itemName,
  }) async {
    try {
      const title = '❌ Out of Stock';
      final body = '$itemName is now out of stock';
      await _notificationService.sendNotification(title, body,
          id: _getNotificationId('out_of_stock', businessId));
    } catch (e) {
      debugPrint('Error notifying out of stock: $e');
    }
  }

  /// Notify about expiry alerts (pharmacy, food, etc.)
  Future<void> notifyExpiryWarning({
    required String businessId,
    required String itemName,
    required DateTime expiryDate,
    required int daysUntilExpiry,
  }) async {
    try {
      const title = '📅 Expiry Warning';
      final body = '$itemName expires in $daysUntilExpiry days';

      // Schedule notification for the day before expiry if enough time
      if (daysUntilExpiry > 1) {
        final notifyDate = expiryDate.subtract(const Duration(days: 1));
        if (notifyDate.isAfter(DateTime.now())) {
          await _notificationService.scheduleNotificationAt(
            id: _getNotificationId('expiry_warning', businessId),
            title: title,
            body: body,
            at: notifyDate,
          );
          return;
        }
      }

      // Immediate notification if expiry is very soon
      await _notificationService.sendNotification(title, body,
          id: _getNotificationId('expiry_warning', businessId));
    } catch (e) {
      debugPrint('Error notifying expiry warning: $e');
    }
  }

  /// ===== PAYMENT NOTIFICATIONS =====

  /// Notify when payment is received
  Future<void> notifyPaymentReceived({
    required String businessId,
    required String customerName,
    required double amount,
    required String transactionId,
  }) async {
    try {
      const title = '💳 Payment Received';
      final body =
          '$customerName: ${amount.toStringAsFixed(2)} (ID: $transactionId)';
      await _notificationService.sendNotification(title, body,
          id: _getNotificationId('payment_received', businessId));
    } catch (e) {
      debugPrint('Error notifying payment received: $e');
    }
  }

  /// Notify when payment fails
  Future<void> notifyPaymentFailed({
    required String businessId,
    required String customerName,
    required double amount,
    required String reason,
  }) async {
    try {
      const title = '❌ Payment Failed';
      final body = '$customerName: ${amount.toStringAsFixed(2)} - $reason';
      await _notificationService.sendNotification(title, body,
          id: _getNotificationId('payment_failed', businessId));
    } catch (e) {
      debugPrint('Error notifying payment failed: $e');
    }
  }

  /// Notify when payment is refunded
  Future<void> notifyPaymentRefunded({
    required String businessId,
    required String customerName,
    required double amount,
  }) async {
    try {
      const title = '↩️ Refund Processed';
      final body = '$customerName: ${amount.toStringAsFixed(2)}';
      await _notificationService.sendNotification(title, body,
          id: _getNotificationId('refund_processed', businessId));
    } catch (e) {
      debugPrint('Error notifying refund: $e');
    }
  }

  /// ===== APPOINTMENT NOTIFICATIONS (Salon, Hotel, etc.) =====

  /// Notify about upcoming appointment
  Future<void> notifyUpcomingAppointment({
    required String businessId,
    required String clientName,
    required String serviceName,
    required DateTime appointmentTime,
  }) async {
    try {
      const title = '📅 Appointment Reminder';
      final body =
          '$clientName - $serviceName at ${_formatTime(appointmentTime)}';

      // Schedule 1 hour before appointment
      final notifyTime = appointmentTime.subtract(const Duration(hours: 1));
      if (notifyTime.isAfter(DateTime.now())) {
        await _notificationService.scheduleNotificationAt(
          id: _getNotificationId('appointment_reminder', businessId),
          title: title,
          body: body,
          at: notifyTime,
        );
      }
    } catch (e) {
      debugPrint('Error notifying appointment reminder: $e');
    }
  }

  /// Notify when appointment is completed
  Future<void> notifyAppointmentCompleted({
    required String businessId,
    required String clientName,
    required String serviceName,
  }) async {
    try {
      const title = '✅ Appointment Completed';
      final body = '$clientName - $serviceName';
      await _notificationService.sendNotification(title, body,
          id: _getNotificationId('appointment_completed', businessId));
    } catch (e) {
      debugPrint('Error notifying appointment completed: $e');
    }
  }

  /// Notify when appointment is cancelled
  Future<void> notifyAppointmentCancelled({
    required String businessId,
    required String clientName,
    required String serviceName,
  }) async {
    try {
      const title = '❌ Appointment Cancelled';
      final body = '$clientName - $serviceName';
      await _notificationService.sendNotification(title, body,
          id: _getNotificationId('appointment_cancelled', businessId));
    } catch (e) {
      debugPrint('Error notifying appointment cancelled: $e');
    }
  }

  /// ===== MEMBERSHIP NOTIFICATIONS (Gym, Hotel, etc.) =====

  /// Notify when membership is expiring
  Future<void> notifyMembershipExpiring({
    required String businessId,
    required String memberName,
    required DateTime expiryDate,
  }) async {
    try {
      final daysLeft = expiryDate.difference(DateTime.now()).inDays;
      const title = '⏰ Membership Expiring';
      final body = '$memberName expires in $daysLeft days';

      if (daysLeft > 1) {
        // Schedule for 1 day before
        final notifyDate = expiryDate.subtract(const Duration(days: 1));
        await _notificationService.scheduleNotificationAt(
          id: _getNotificationId('membership_expiry', businessId),
          title: title,
          body: body,
          at: notifyDate,
        );
      } else {
        // Send immediately if less than 1 day
        await _notificationService.sendNotification(title, body,
            id: _getNotificationId('membership_expiry', businessId));
      }
    } catch (e) {
      debugPrint('Error notifying membership expiry: $e');
    }
  }

  /// Notify when membership is renewed
  Future<void> notifyMembershipRenewed({
    required String businessId,
    required String memberName,
    required DateTime newExpiryDate,
  }) async {
    try {
      const title = '🎉 Membership Renewed';
      final body = '$memberName - Valid until ${_formatDate(newExpiryDate)}';
      await _notificationService.sendNotification(title, body,
          id: _getNotificationId('membership_renewed', businessId));
    } catch (e) {
      debugPrint('Error notifying membership renewed: $e');
    }
  }

  /// ===== ORDER NOTIFICATIONS (Restaurant, Retail, etc.) =====

  /// Notify when order is placed
  Future<void> notifyOrderPlaced({
    required String businessId,
    required String orderId,
    required int itemCount,
    required double total,
  }) async {
    try {
      const title = '📦 New Order';
      final body =
          'Order #$orderId - $itemCount items - ${total.toStringAsFixed(2)}';
      await _notificationService.sendNotification(title, body,
          id: _getNotificationId('order_placed', businessId));
    } catch (e) {
      debugPrint('Error notifying order placed: $e');
    }
  }

  /// Notify when order is being prepared
  Future<void> notifyOrderBeingPrepared({
    required String businessId,
    required String orderId,
  }) async {
    try {
      const title = '👨‍🍳 Preparing Order';
      final body = 'Order #$orderId is being prepared';
      await _notificationService.sendNotification(title, body,
          id: _getNotificationId('order_preparing', businessId));
    } catch (e) {
      debugPrint('Error notifying order preparing: $e');
    }
  }

  /// Notify when order is ready
  Future<void> notifyOrderReady({
    required String businessId,
    required String orderId,
    required String orderType,
  }) async {
    try {
      const title = '🎉 Order Ready';
      final body = 'Order #$orderId is ready for $orderType';
      await _notificationService.sendNotification(title, body,
          id: _getNotificationId('order_ready', businessId));
    } catch (e) {
      debugPrint('Error notifying order ready: $e');
    }
  }

  /// Notify when order is delivered
  Future<void> notifyOrderDelivered({
    required String businessId,
    required String orderId,
    required String customerName,
  }) async {
    try {
      const title = '✅ Order Delivered';
      final body = 'Order #$orderId delivered to $customerName';
      await _notificationService.sendNotification(title, body,
          id: _getNotificationId('order_delivered', businessId));
    } catch (e) {
      debugPrint('Error notifying order delivered: $e');
    }
  }

  /// Notify when order is cancelled
  Future<void> notifyOrderCancelled({
    required String businessId,
    required String orderId,
    required String reason,
  }) async {
    try {
      const title = '❌ Order Cancelled';
      final body = 'Order #$orderId - Reason: $reason';
      await _notificationService.sendNotification(title, body,
          id: _getNotificationId('order_cancelled', businessId));
    } catch (e) {
      debugPrint('Error notifying order cancelled: $e');
    }
  }

  /// ===== BOOKING NOTIFICATIONS (Hotel, Real Estate, etc.) =====

  /// Notify about upcoming booking/check-in
  Future<void> notifyUpcomingCheckIn({
    required String businessId,
    required String guestName,
    required String roomNumber,
    required DateTime checkInTime,
  }) async {
    try {
      const title = '🏨 Upcoming Check-in';
      final body =
          '$guestName - Room $roomNumber at ${_formatTime(checkInTime)}';

      // Schedule 2 hours before check-in
      final notifyTime = checkInTime.subtract(const Duration(hours: 2));
      if (notifyTime.isAfter(DateTime.now())) {
        await _notificationService.scheduleNotificationAt(
          id: _getNotificationId('checkin_reminder', businessId),
          title: title,
          body: body,
          at: notifyTime,
        );
      }
    } catch (e) {
      debugPrint('Error notifying check-in reminder: $e');
    }
  }

  /// Notify when booking is confirmed
  Future<void> notifyBookingConfirmed({
    required String businessId,
    required String bookingId,
    required String guestName,
  }) async {
    try {
      const title = '✅ Booking Confirmed';
      final body = '$guestName - Booking #$bookingId';
      await _notificationService.sendNotification(title, body,
          id: _getNotificationId('booking_confirmed', businessId));
    } catch (e) {
      debugPrint('Error notifying booking confirmed: $e');
    }
  }

  /// ===== WORKER/STAFF NOTIFICATIONS =====

  /// Notify worker about assignment
  Future<void> notifyWorkerAssignment({
    required String businessId,
    required String workerName,
    required String taskName,
    required DateTime dueDate,
  }) async {
    try {
      const title = '📋 New Assignment';
      final body = '$taskName - Due: ${_formatDate(dueDate)}';
      await _notificationService.sendNotification(title, body,
          id: _getNotificationId('worker_assignment', businessId));
    } catch (e) {
      debugPrint('Error notifying worker assignment: $e');
    }
  }

  /// Notify about shift reminder
  Future<void> notifyShiftReminder({
    required String businessId,
    required String workerName,
    required DateTime shiftTime,
  }) async {
    try {
      const title = '⏰ Shift Reminder';
      final body = '$workerName - Shift at ${_formatTime(shiftTime)}';

      // Schedule 1 hour before shift
      final notifyTime = shiftTime.subtract(const Duration(hours: 1));
      if (notifyTime.isAfter(DateTime.now())) {
        await _notificationService.scheduleNotificationAt(
          id: _getNotificationId('shift_reminder', businessId),
          title: title,
          body: body,
          at: notifyTime,
        );
      }
    } catch (e) {
      debugPrint('Error notifying shift reminder: $e');
    }
  }

  /// ===== GENERAL NOTIFICATIONS =====

  /// Notify about maintenance/system events
  Future<void> notifyMaintenance({
    required String title,
    required String message,
    required DateTime startTime,
    required Duration duration,
  }) async {
    try {
      await _notificationService.sendNotification(title, message,
          id: _getNotificationId('maintenance', ''));
    } catch (e) {
      debugPrint('Error notifying maintenance: $e');
    }
  }

  /// Notify about sync status
  Future<void> notifySyncStatus({
    required bool isOnline,
    required String businessId,
  }) async {
    try {
      if (isOnline) {
        const title = '🔄 Sync Complete';
        const body = 'All data synced successfully';
        await _notificationService.sendNotification(title, body,
            id: _getNotificationId('sync_online', businessId));
      } else {
        const title = '📴 Offline Mode';
        const body =
            'You are currently offline. Changes will sync when online.';
        await _notificationService.sendNotification(title, body,
            id: _getNotificationId('sync_offline', businessId));
      }
    } catch (e) {
      debugPrint('Error notifying sync status: $e');
    }
  }

  /// Notify about subscription status
  Future<void> notifySubscriptionStatus({
    required String businessId,
    required String status,
    required String? message,
  }) async {
    try {
      String title = '';
      String body = message ?? '';

      switch (status.toLowerCase()) {
        case 'active':
          title = '✅ Subscription Active';
          break;
        case 'expiring':
          title = '⏰ Subscription Expiring';
          break;
        case 'expired':
          title = '❌ Subscription Expired';
          break;
        case 'cancelled':
          title = '❌ Subscription Cancelled';
          break;
        default:
          title = 'Subscription Status';
      }

      await _notificationService.sendNotification(title, body,
          id: _getNotificationId('subscription_status', businessId));
    } catch (e) {
      debugPrint('Error notifying subscription status: $e');
    }
  }

  /// ===== HELPER METHODS =====

  /// Generate unique notification ID
  int _getNotificationId(String type, String businessId) {
    _notificationCounter++;
    return (type.hashCode ^ businessId.hashCode) + _notificationCounter;
  }

  /// Format time for notification display
  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  /// Format date for notification display
  String _formatDate(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
  }

  /// Cancel all pending notifications
  Future<void> cancelAllNotifications() async {
    try {
      await _notificationService.cancelAllNotifications();
    } catch (e) {
      debugPrint('Error cancelling all notifications: $e');
    }
  }

  /// Get all pending notifications
  Future<List<Object>> getPendingNotifications() async {
    try {
      return await _notificationService.getPendingNotifications();
    } catch (e) {
      debugPrint('Error getting pending notifications: $e');
      return [];
    }
  }
}

/// Model for pending notifications
class PendingNotificationRequest {
  final int id;
  final String? title;
  final String? body;

  PendingNotificationRequest({
    required this.id,
    this.title,
    this.body,
  });
}

extension on NotificationService {}

