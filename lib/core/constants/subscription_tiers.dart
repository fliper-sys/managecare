/// Subscription tiers
enum SubscriptionTier {
  free,
  starter,
  professional,
  enterprise,
}

extension SubscriptionTierExtension on SubscriptionTier {
  String get displayName {
    switch (this) {
      case SubscriptionTier.free:
        return 'Free';
      case SubscriptionTier.starter:
        return 'Starter';
      case SubscriptionTier.professional:
        return 'Professional';
      case SubscriptionTier.enterprise:
        return 'Enterprise';
    }
  }

  double get monthlyPrice {
    switch (this) {
      case SubscriptionTier.free:
        return 0.0;
      case SubscriptionTier.starter:
        return 29.99;
      case SubscriptionTier.professional:
        return 79.99;
      case SubscriptionTier.enterprise:
        return 299.99;
    }
  }

  List<String> get features {
    switch (this) {
      case SubscriptionTier.free:
        return [
          'Basic sales tracking',
          'Up to 300 products',
          'Mobile app access',
        ];
      case SubscriptionTier.starter:
        return [
          'All free features',
          'Up to 600 products',
          'Advanced reports',
          'Email support',
          'Whatsapp Messages',
        ];
      case SubscriptionTier.professional:
        return [
          'All starter features',
          'Unlimited products',
          'Employee management',
          'Priority support',
          'Custom integrations',
        ];
      case SubscriptionTier.enterprise:
        return [
          'All professional features',
          'Dedicated account manager',
          'Custom development',
          '24/7 phone support',
          'Multi-location support',
        ];
    }
  }

  int get maxProducts {
    switch (this) {
      case SubscriptionTier.free:
        return 50;
      case SubscriptionTier.starter:
        return 500;
      case SubscriptionTier.professional:
      case SubscriptionTier.enterprise:
        return 999999;
    }
  }

  int get maxUsers {
    switch (this) {
      case SubscriptionTier.free:
        return 1;
      case SubscriptionTier.starter:
        return 5;
      case SubscriptionTier.professional:
        return 20;
      case SubscriptionTier.enterprise:
        return 999;
    }
  }
}

