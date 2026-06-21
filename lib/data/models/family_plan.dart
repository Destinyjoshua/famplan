class FamilyPlanCatalog {
  FamilyPlanCatalog._();

  static const free = FamilyPlanOption(
    id: 'free',
    name: 'Free',
    priceNgn: 0,
    interval: 'forever',
    description: 'Everything you need to coordinate your family.',
    features: [
      'Tasks & chores',
      'Shared calendar',
      'Meal planning',
      'Family announcements',
      'Family health insights',
    ],
  );

  static const premium = FamilyPlanOption(
    id: 'premium',
    name: 'Premium',
    priceNgn: 1000,
    interval: 'month',
    description: 'Advanced coordination for busy families.',
    features: [
      'Everything in Free',
      'Priority support',
      'Advanced family analytics',
      'Unlimited family members',
      'Early access to new features',
    ],
  );

  static const all = [free, premium];

  static FamilyPlanOption byId(String id) {
    return all.firstWhere(
      (plan) => plan.id == id,
      orElse: () => free,
    );
  }
}

class FamilyPlanOption {
  const FamilyPlanOption({
    required this.id,
    required this.name,
    required this.priceNgn,
    required this.interval,
    required this.description,
    required this.features,
  });

  final String id;
  final String name;
  final int priceNgn;
  final String interval;
  final String description;
  final List<String> features;

  bool get isFree => priceNgn == 0;

  String get priceLabel {
    if (isFree) return 'Free';
    return '₦${priceNgn.toStringAsFixed(0)}/$interval';
  }
}

class FamilySubscription {
  const FamilySubscription({
    required this.planId,
    required this.planStatus,
    this.planStartedAt,
    this.planExpiresAt,
  });

  final String planId;
  final String planStatus;
  final DateTime? planStartedAt;
  final DateTime? planExpiresAt;

  FamilyPlanOption get plan => FamilyPlanCatalog.byId(planId);

  bool get isPremium => planId == 'premium' && planStatus == 'active';

  factory FamilySubscription.fromFamilyJson(Map<String, dynamic> json) {
    return FamilySubscription(
      planId: json['plan_id'] as String? ?? 'free',
      planStatus: json['plan_status'] as String? ?? 'active',
      planStartedAt: json['plan_started_at'] != null
          ? DateTime.parse(json['plan_started_at'] as String)
          : null,
      planExpiresAt: json['plan_expires_at'] != null
          ? DateTime.parse(json['plan_expires_at'] as String)
          : null,
    );
  }
}