import 'package:famplan/core/theme/app_theme.dart';
import 'package:famplan/data/models/announcement.dart';
import 'package:famplan/data/models/event.dart';
import 'package:famplan/data/models/meal.dart';
import 'package:famplan/data/models/task.dart';
import 'package:famplan/providers/auth_provider.dart';
import 'package:famplan/providers/dashboard_provider.dart';
import 'package:famplan/providers/family_health_provider.dart';
import 'package:famplan/providers/family_provider.dart';
import 'package:famplan/providers/plan_provider.dart';
import 'package:famplan/providers/task_provider.dart';
import 'package:famplan/shared/widgets/empty_state.dart';
import 'package:famplan/shared/widgets/invite_family_sheet.dart';
import 'package:famplan/shared/widgets/loading_view.dart';
import 'package:famplan/shared/widgets/section_card.dart';
import 'package:famplan/shared/widgets/stat_chip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(currentFamilyProvider);
    final profileAsync = ref.watch(profileProvider);

    return familyAsync.when(
      loading: () => const Scaffold(body: LoadingView(message: 'Loading family...')),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (family) {
        if (family == null) {
          return const Scaffold(
            body: EmptyState(
              icon: Icons.family_restroom,
              title: 'No family found',
              subtitle: 'Complete onboarding to get started.',
            ),
          );
        }

        final dashboardAsync = ref.watch(dashboardProvider(family.id));
        final healthAsync = ref.watch(familyHealthProvider(family.id));
        final subscriptionAsync = ref.watch(familySubscriptionProvider);
        final tasksAsync = ref.watch(tasksStreamProvider(family.id));
        final pendingTasks =
            tasksAsync.value?.where((t) => !t.isCompleted).length ?? 0;
        final overdueTasks =
            tasksAsync.value?.where((t) => t.isOverdue).length ?? 0;

        final displayName = profileAsync.value?.displayName;
        final greeting = _greeting(displayName);

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                Text(family.name),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.person_add_outlined),
                tooltip: 'Invite family',
                onPressed: () => InviteFamilySheet.show(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.groups_outlined),
                tooltip: 'Family management',
                onPressed: () => context.push('/family'),
              ),
            ],
          ),
          body: dashboardAsync.when(
            loading: () => const LoadingView(message: 'Loading dashboard...'),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (dashboard) => RefreshIndicator(
              onRefresh: () => ref
                  .read(dashboardControllerProvider.notifier)
                  .refresh(family.id)
                  .then((_) {}),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _HeroHeader(date: dashboard.date),
                  const SizedBox(height: 14),
                  healthAsync.when(
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (health) => Column(
                      children: [
                        _FamilyHealthBanner(
                          score: health.score,
                          label: health.label,
                          planLabel: subscriptionAsync.value?.plan.name ?? 'Free',
                          onTap: () => context.push('/health'),
                        ),
                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      StatChip(
                        icon: Icons.task_alt,
                        label: 'Open tasks',
                        value: '$pendingTasks',
                        color: AppTheme.coral,
                      ),
                      const SizedBox(width: 10),
                      StatChip(
                        icon: Icons.warning_amber_rounded,
                        label: 'Overdue',
                        value: '$overdueTasks',
                        color: overdueTasks > 0
                            ? Theme.of(context).colorScheme.error
                            : AppTheme.amber,
                      ),
                      const SizedBox(width: 10),
                      StatChip(
                        icon: Icons.event,
                        label: 'Today',
                        value: '${dashboard.events.length}',
                        color: AppTheme.teal,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _InviteBanner(
                    inviteCode: family.inviteCode,
                    onTap: () => InviteFamilySheet.show(context, ref),
                  ),
                  const SizedBox(height: 14),
                  SectionCard(
                    title: 'Tasks',
                    icon: Icons.check_circle_outline,
                    color: AppTheme.coral,
                    emptyMessage: 'No tasks for today — add one in Tasks',
                    onSeeAll: () => context.go('/tasks'),
                    children: dashboard.tasks
                        .map((t) => _TaskTile(task: t, familyId: family.id))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Events',
                    icon: Icons.event_outlined,
                    color: AppTheme.teal,
                    emptyMessage: 'Nothing on the calendar today',
                    onSeeAll: () => context.go('/calendar'),
                    children: dashboard.events
                        .map((e) => _EventTile(event: e))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Meals',
                    icon: Icons.restaurant_outlined,
                    color: AppTheme.amber,
                    emptyMessage: 'No meals planned for today',
                    onSeeAll: () => context.go('/meals'),
                    children: dashboard.meals
                        .map((m) => _MealTile(meal: m))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  SectionCard(
                    title: 'Announcements',
                    icon: Icons.campaign_outlined,
                    color: AppTheme.violet,
                    emptyMessage: 'No family updates yet',
                    onSeeAll: () => context.go('/announcements'),
                    children: dashboard.announcements
                        .map((a) => _AnnouncementTile(announcement: a))
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _greeting(String? name) {
    final hour = DateTime.now().hour;
    final time = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    if (name == null || name.isEmpty) return time;
    final first = name.split(' ').first;
    return '$time, $first';
  }
}

class _FamilyHealthBanner extends StatelessWidget {
  const _FamilyHealthBanner({
    required this.score,
    required this.label,
    required this.planLabel,
    required this.onTap,
  });

  final int score;
  final String label;
  final String planLabel;
  final VoidCallback onTap;

  Color get _scoreColor {
    if (score >= 80) return AppTheme.teal;
    if (score >= 60) return const Color(0xFF5CB85C);
    if (score >= 40) return AppTheme.amber;
    return AppTheme.coral;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: _scoreColor.withValues(alpha: 0.12),
                child: Text(
                  '$score',
                  style: TextStyle(
                    color: _scoreColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Family health · $label',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$planLabel plan · Tap for full analysis',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.favorite_outline, color: AppTheme.coral),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.coral, Color(0xFFFF8E8E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.coral.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE').format(date),
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMMM d').format(date),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Here\'s what\'s happening in your family today',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          const Icon(Icons.wb_sunny_outlined, color: Colors.white, size: 40),
        ],
      ),
    );
  }
}

class _InviteBanner extends StatelessWidget {
  const _InviteBanner({required this.inviteCode, required this.onTap});

  final String? inviteCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.person_add, color: AppTheme.teal),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Invite family members',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      inviteCode != null
                          ? 'Share code $inviteCode'
                          : 'Tap to get your invite code',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task, required this.familyId});

  final Task task;
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CheckboxListTile(
      value: task.isCompleted,
      onChanged: task.isCompleted
          ? null
          : (_) => ref.read(taskControllerProvider.notifier).completeTask(task.id),
      title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: task.dueAt != null
          ? Text(DateFormat('MMM d, h:mm a').format(task.dueAt!))
          : null,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final Event event;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: AppTheme.teal.withValues(alpha: 0.12),
        child: const Icon(Icons.schedule, size: 18, color: AppTheme.teal),
      ),
      title: Text(event.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        event.allDay ? 'All day' : DateFormat('h:mm a').format(event.startsAt),
      ),
    );
  }
}

class _MealTile extends StatelessWidget {
  const _MealTile({required this.meal});

  final MealSlot meal;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: AppTheme.amber.withValues(alpha: 0.15),
        child: const Icon(Icons.restaurant, size: 18, color: AppTheme.amber),
      ),
      title: Text(
        meal.mealName ?? 'No meal set',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${meal.mealType[0].toUpperCase()}${meal.mealType.substring(1)}'
        '${meal.cook != null ? ' · ${meal.cook!.displayName}' : ''}',
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: AppTheme.violet.withValues(alpha: 0.12),
        child: Icon(
          announcement.isPinned ? Icons.push_pin : Icons.chat_bubble_outline,
          size: 18,
          color: AppTheme.violet,
        ),
      ),
      title: Text(
        announcement.body,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(DateFormat('MMM d').format(announcement.createdAt)),
    );
  }
}