import 'package:famplan/core/theme/app_theme.dart';
import 'package:famplan/core/utils/responsive.dart';
import 'package:famplan/data/models/family_health.dart';
import 'package:famplan/providers/family_health_provider.dart';
import 'package:famplan/providers/family_provider.dart';
import 'package:famplan/shared/widgets/empty_state.dart';
import 'package:famplan/shared/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FamilyHealthScreen extends ConsumerWidget {
  const FamilyHealthScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(currentFamilyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Family Health')),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: pageMaxWidth(context)),
          child: familyAsync.when(
            loading: () => const LoadingView(message: 'Loading family...'),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (family) {
              if (family == null) {
                return const EmptyState(
                  icon: Icons.family_restroom,
                  title: 'No family found',
                  subtitle: 'Join or create a family to see health insights.',
                );
              }

              final healthAsync = ref.watch(familyHealthProvider(family.id));

              return healthAsync.when(
                loading: () => const LoadingView(message: 'Analyzing activity...'),
                error: (e, _) => Center(child: Text('Error: $e')),
                data: (health) => RefreshIndicator(
                  onRefresh: () => ref
                      .read(familyHealthControllerProvider.notifier)
                      .refresh(family.id)
                      .then((_) {}),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _HealthScoreCard(health: health),
                      const SizedBox(height: 16),
                      Text(
                        'Activity breakdown',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      _MetricGrid(metrics: health.metrics),
                      const SizedBox(height: 16),
                      Text(
                        'Insights',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ...health.insights.map(
                        (insight) => _InsightTile(text: insight),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HealthScoreCard extends StatelessWidget {
  const _HealthScoreCard({required this.health});

  final FamilyHealth health;

  Color get _color {
    if (health.score >= 80) return AppTheme.teal;
    if (health.score >= 60) return const Color(0xFF5CB85C);
    if (health.score >= 40) return AppTheme.amber;
    return AppTheme.coral;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _color.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: health.score / 100,
                  strokeWidth: 10,
                  backgroundColor: _color.withValues(alpha: 0.15),
                  color: _color,
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${health.score}',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: _color,
                          ),
                    ),
                    Text(
                      '/ 100',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            health.label,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Based on the last ${health.periodDays} days of family activity',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.65),
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final FamilyHealthMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Tasks done', '${metrics.tasksCompleted}/${metrics.tasksCreated}', metrics.taskScore, AppTheme.coral),
      ('Calendar', '${metrics.upcomingEvents} upcoming', metrics.calendarScore, AppTheme.teal),
      ('Updates', '${metrics.announcements} posts', metrics.communicationScore, AppTheme.violet),
      ('Meals', '${metrics.mealsPlanned}/${metrics.mealsTotal}', metrics.mealScore, AppTheme.amber),
      ('Engagement', '${metrics.engagedMembers}/${metrics.activeMembers} members', metrics.engagementScore, const Color(0xFF5CB85C)),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: items
          .map(
            (item) => SizedBox(
              width: 160,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.$1,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$2,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: item.$3 / 100,
                        minHeight: 6,
                        borderRadius: BorderRadius.circular(4),
                        backgroundColor: item.$4.withValues(alpha: 0.15),
                        color: item.$4,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.teal.withValues(alpha: 0.12),
          child: const Icon(Icons.lightbulb_outline, color: AppTheme.teal, size: 20),
        ),
        title: Text(text),
      ),
    );
  }
}