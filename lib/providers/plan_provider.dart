import 'package:famplan/data/models/family_plan.dart';
import 'package:famplan/providers/family_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final familySubscriptionProvider = FutureProvider<FamilySubscription>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) {
    return const FamilySubscription(planId: 'free', planStatus: 'active');
  }
  return family.subscription;
});