import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/datetime_utils.dart';

class AdminNotification {
  final String id;
  final String type; // 'payment', 'business', 'user', 'subscription'
  final String title;
  final String message;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime createdAt;

  AdminNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.data,
    this.isRead = false,
    required this.createdAt,
  });

  factory AdminNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AdminNotification(
      id: doc.id,
      type: data['type'] ?? 'general',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      data: data['data'] ?? {},
      isRead: data['isRead'] ?? false,
      createdAt: parseTimestamp(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'title': title,
        'message': message,
        'data': data,
        'isRead': isRead,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}

