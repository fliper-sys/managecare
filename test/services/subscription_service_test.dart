import 'package:flutter_test/flutter_test.dart';
import 'package:business_manager/services/subscription_service.dart';
import 'package:business_manager/data/models/user_model.dart';

void main() {
  group('SubscriptionService.detectTier', () {
    test('returns pro for very high metrics (enterprise behavior now mapped to pro)', () {
      expect(SubscriptionService.detectTier(products: 1500, staff: 5, monthlyIncome: 100000.0), 'pro');
      expect(SubscriptionService.detectTier(products: 10, staff: 60, monthlyIncome: 1000.0), 'pro');
      expect(SubscriptionService.detectTier(products: 10, staff: 1, monthlyIncome: 6000000.0), 'pro');
    });

    test('returns pro for moderate metrics', () {
      expect(SubscriptionService.detectTier(products: 400, staff: 2, monthlyIncome: 1000.0), 'pro');
      expect(SubscriptionService.detectTier(products: 10, staff: 10, monthlyIncome: 1000.0), 'pro');
      expect(SubscriptionService.detectTier(products: 10, staff: 1, monthlyIncome: 600000.0), 'pro');
    });

    test('returns basic for low metrics', () {
      expect(SubscriptionService.detectTier(products: 50, staff: 1, monthlyIncome: 2000.0), 'basic');
      expect(SubscriptionService.detectTier(products: 399, staff: 1, monthlyIncome: 499999.0), 'basic');
    });
  });

  group('SubscriptionService.getPlanById', () {
    test('returns plan for valid id', () {
      final plan = SubscriptionService.getPlanById('t1_basic_3m');
      expect(plan, isNotNull);
      expect(plan!.id, 't1_basic_3m');
    });

    test('returns null for invalid id', () {
      final plan = SubscriptionService.getPlanById('nonexistent_plan');
      expect(plan, isNull);
    });
  });

  group('SubscriptionService.detectBusinessClass', () {
    test('detects tier1 for small businesses', () {
      expect(SubscriptionService.detectBusinessClass(products: 300, staff: 2, monthlyIncome: 100000.0), 'tier1');
    });

    test('detects tier2 for mid-sized businesses', () {
      expect(SubscriptionService.detectBusinessClass(products: 500, staff: 5, monthlyIncome: 1500000.0), 'tier2');
    });

    test('detects tier3 for others', () {
      expect(SubscriptionService.detectBusinessClass(products: 1200, staff: 20, monthlyIncome: 3000000.0), 'tier3');
      expect(SubscriptionService.detectBusinessClass(products: 400, staff: 3, monthlyIncome: 200000.0), 'tier3');
    });
  });

  group('SubscriptionService.isSubscriptionActive', () {
    test('non-owners are granted access regardless of subscription', () {
      final user = UserModel(
        id: 'u1',
        email: 'worker@example.com',
        fullName: 'Worker',
        role: 'cashier',
        businessId: 'b1',
        isActive: true,
        isOwner: false,
        hasActiveSubscription: false,
      );
      expect(SubscriptionService.isSubscriptionActive(user), isTrue);
    });

    test('owner with expired subscription is denied access', () {
      final user = UserModel(
        id: 'u2',
        email: 'owner@example.com',
        fullName: 'Owner',
        role: 'owner',
        businessId: 'b1',
        isActive: true,
        isOwner: true,
        hasActiveSubscription: false,
        subscriptionEndDate: DateTime.now().subtract(const Duration(days: 1)),
      );
      expect(SubscriptionService.isSubscriptionActive(user), isFalse);
    });

    test('owner with valid subscription is granted access', () {
      final user = UserModel(
        id: 'u3',
        email: 'owner2@example.com',
        fullName: 'Owner2',
        role: 'owner',
        businessId: 'b1',
        isActive: true,
        isOwner: true,
        hasActiveSubscription: true,
        subscriptionEndDate: DateTime.now().add(const Duration(days: 30)),
      );
      expect(SubscriptionService.isSubscriptionActive(user), isTrue);
    });
  });

}
