import 'package:famplan/core/theme/app_theme.dart';
import 'package:famplan/core/utils/responsive.dart';
import 'package:famplan/data/models/family_plan.dart';
import 'package:famplan/providers/family_provider.dart';
import 'package:famplan/providers/plan_provider.dart';
import 'package:famplan/shared/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscriptionAsync = ref.watch(familySubscriptionProvider);
    final membershipAsync = ref.watch(currentFamilyMembershipProvider);
    final isAdmin = membershipAsync.value?.isAdmin ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Plans')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: pageMaxWidth(context)),
          child: subscriptionAsync.when(
            loading: () => const LoadingView(message: 'Loading plan...'),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (subscription) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _LaunchBanner(),
                const SizedBox(height: 16),
                ...FamilyPlanCatalog.all.map(
                  (plan) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PlanCard(
                      plan: plan,
                      isCurrent: subscription.planId == plan.id,
                      isAdmin: isAdmin,
                      onSelect: () => _handlePlanSelect(context, plan, subscription),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handlePlanSelect(
    BuildContext context,
    FamilyPlanOption plan,
    FamilySubscription subscription,
  ) {
    if (plan.id == subscription.planId) return;

    if (plan.isFree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You are already on the Free plan.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Premium is ₦1,000/month. Billing launches soon — everyone is on Free for now.',
        ),
      ),
    );
  }
}

class _LaunchBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.teal, Color(0xFF4EDDD0)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        children: [
          Icon(Icons.celebration_outlined, color: Colors.white, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Launch offer: all families are on the Free plan while we roll out billing.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.plan,
    required this.isCurrent,
    required this.isAdmin,
    required this.onSelect,
  });

  final FamilyPlanOption plan;
  final bool isCurrent;
  final bool isAdmin;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final isPremium = plan.id == 'premium';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        plan.priceLabel,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: isPremium ? AppTheme.coral : AppTheme.teal,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                ),
                if (isCurrent)
                  Chip(
                    label: const Text('Current plan'),
                    backgroundColor: AppTheme.teal.withValues(alpha: 0.15),
                    labelStyle: const TextStyle(color: AppTheme.teal),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(plan.description),
            const SizedBox(height: 14),
            ...plan.features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 18,
                      color: isPremium ? AppTheme.coral : AppTheme.teal,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(feature)),
                  ],
                ),
              ),
            ),
            if (!isCurrent) ...[
              const SizedBox(height: 16),
              FilledButton(
                onPressed: isAdmin ? onSelect : null,
                style: FilledButton.styleFrom(
                  backgroundColor: isPremium ? AppTheme.coral : AppTheme.teal,
                ),
                child: Text(
                  plan.isFree
                      ? 'Downgrade'
                      : 'Upgrade to Premium',
                ),
              ),
              if (!isAdmin)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Only family admins can change plans.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}