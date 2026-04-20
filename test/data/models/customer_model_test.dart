import 'package:business_manager/data/models/customer_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CustomerModel', () {
    test('normalizes legacy Firestore customer fields', () {
      final createdAt = DateTime(2026, 1, 10, 9, 0);
      final updatedAt = DateTime(2026, 1, 12, 18, 30);

      final customer = CustomerModel.fromJson(
        {
          'businessId': 'biz_1',
          'fullName': 'Ada Lovelace',
          'phoneNumber': '08012345678',
          'email': 'ada@example.com',
          'totalPurchases': 6000,
          'totalOrders': 3,
          'createdAt': Timestamp.fromDate(createdAt),
          'updatedAt': Timestamp.fromDate(updatedAt),
          'isActive': 1,
        },
        documentId: 'cust_1',
      );

      expect(customer.id, 'cust_1');
      expect(customer.businessId, 'biz_1');
      expect(customer.name, 'Ada Lovelace');
      expect(customer.phone, '08012345678');
      expect(customer.email, 'ada@example.com');
      expect(customer.totalSpent, 6000);
      expect(customer.totalTransactions, 3);
      expect(customer.averageOrderValue, 2000);
      expect(customer.firstPurchaseDate, createdAt);
      expect(customer.lastPurchaseDate, updatedAt);
      expect(customer.isActive, isTrue);
    });

    test('writes canonical and compatibility Firestore fields', () {
      final now = DateTime(2026, 2, 1, 12, 0);
      final customer = CustomerModel(
        id: 'cust_2',
        businessId: 'biz_2',
        name: 'Grace Hopper',
        email: 'grace@example.com',
        phone: '08087654321',
        totalSpent: 9000,
        totalTransactions: 4,
        averageOrderValue: 2250,
        firstPurchaseDate: now,
        lastPurchaseDate: now,
        createdAt: now,
        updatedAt: now,
        isActive: true,
        notes: 'VIP',
      );

      final json = customer.toJson(additionalFields: {
        'customerType': 'Individual',
      });

      expect(json['id'], 'cust_2');
      expect(json['customerId'], 'cust_2');
      expect(json['name'], 'Grace Hopper');
      expect(json['fullName'], 'Grace Hopper');
      expect(json['phone'], '08087654321');
      expect(json['phoneNumber'], '08087654321');
      expect(json['totalSpent'], 9000);
      expect(json['totalPurchases'], 9000);
      expect(json['totalTransactions'], 4);
      expect(json['totalOrders'], 4);
      expect(json['customerType'], 'Individual');
    });
  });
}
