abstract class NotificationRepository {
  Future<List<Map<String, dynamic>>> getNotifications(String userId);

  Future<void> createNotification(
    String userId,
    Map<String, dynamic> notificationData,
  );

  Future<void> markAsRead(String notificationId);

  Future<void> deleteNotification(String notificationId);

  Future<int> getUnreadCount(String userId);
}

