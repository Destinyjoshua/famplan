import 'package:famplan/core/theme/app_theme.dart';
import 'package:famplan/core/utils/responsive.dart';
import 'package:famplan/features/announcements/presentation/announcements_screen.dart';
import 'package:famplan/features/calendar/presentation/calendar_screen.dart';
import 'package:famplan/features/dashboard/presentation/dashboard_screen.dart';
import 'package:famplan/features/meals/presentation/meals_screen.dart';
import 'package:famplan/features/tasks/presentation/tasks_screen.dart';
import 'package:famplan/providers/auth_provider.dart';
import 'package:famplan/providers/family_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class FamilyShell extends ConsumerWidget {
  const FamilyShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard,
      label: 'Home',
      webLabel: 'Dashboard',
    ),
    (
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
      label: 'Calendar',
      webLabel: 'Calendar',
    ),
    (
      icon: Icons.task_alt_outlined,
      selectedIcon: Icons.task_alt,
      label: 'Tasks',
      webLabel: 'Tasks',
    ),
    (
      icon: Icons.restaurant_menu_outlined,
      selectedIcon: Icons.restaurant_menu,
      label: 'Meals',
      webLabel: 'Meals',
    ),
    (
      icon: Icons.campaign_outlined,
      selectedIcon: Icons.campaign,
      label: 'News',
      webLabel: 'Announcements',
    ),
  ];

  void _goToBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (useDesktopLayout(context)) {
      return _DesktopShell(
        navigationShell: navigationShell,
        destinations: _destinations,
        onDestinationSelected: _goToBranch,
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        elevation: 8,
        shadowColor: Colors.black26,
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _goToBranch,
        destinations: _destinations
            .map(
              (d) => NavigationDestination(
                icon: Icon(d.icon),
                selectedIcon: Icon(d.selectedIcon),
                label: d.label,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _DesktopShell extends ConsumerWidget {
  const _DesktopShell({
    required this.navigationShell,
    required this.destinations,
    required this.onDestinationSelected,
  });

  final StatefulNavigationShell navigationShell;
  final List<
      ({
        IconData icon,
        IconData selectedIcon,
        String label,
        String webLabel,
      })> destinations;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyName = ref.watch(currentFamilyProvider).value?.name ?? 'Famplans';
    final profileName =
        ref.watch(profileProvider).value?.displayName ?? 'Family Member';

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            extended: MediaQuery.sizeOf(context).width >= 1100,
            minExtendedWidth: 200,
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: onDestinationSelected,
            leading: Padding(
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              child: Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.coral, AppTheme.teal],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.family_restroom,
                      color: Colors.white,
                    ),
                  ),
                  if (MediaQuery.sizeOf(context).width < 1100) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Famplans',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
            labelType: MediaQuery.sizeOf(context).width >= 1100
                ? NavigationRailLabelType.none
                : NavigationRailLabelType.all,
            destinations: destinations
                .map(
                  (d) => NavigationRailDestination(
                    icon: Icon(d.icon),
                    selectedIcon: Icon(d.selectedIcon),
                    label: Text(d.webLabel),
                  ),
                )
                .toList(),
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Column(
              children: [
                Material(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 0,
                  child: Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: AppTheme.warmBrown.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Row(
                        children: [
                          if (MediaQuery.sizeOf(context).width >= 1100)
                            Text(
                              'Famplans',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          if (MediaQuery.sizeOf(context).width >= 1100)
                            const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  familyName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  profileName,
                                  style: Theme.of(context).textTheme.bodySmall,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextButton.icon(
                                onPressed: () => context.push('/family'),
                                icon: const Icon(Icons.groups_outlined, size: 18),
                                label: const Text('Family'),
                              ),
                              const SizedBox(width: 4),
                              TextButton.icon(
                                onPressed: () => ref
                                    .read(authControllerProvider.notifier)
                                    .signOut(),
                                icon: const Icon(Icons.logout, size: 18),
                                label: const Text('Sign out'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: pageMaxWidth(context),
                      ),
                      child: navigationShell,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FamilyShellBranch extends StatelessWidget {
  const FamilyShellBranch({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class DashboardBranch extends StatelessWidget {
  const DashboardBranch({super.key});
  @override
  Widget build(BuildContext context) => const DashboardScreen();
}

class CalendarBranch extends StatelessWidget {
  const CalendarBranch({super.key});
  @override
  Widget build(BuildContext context) => const CalendarScreen();
}

class TasksBranch extends StatelessWidget {
  const TasksBranch({super.key});
  @override
  Widget build(BuildContext context) => const TasksScreen();
}

class MealsBranch extends StatelessWidget {
  const MealsBranch({super.key});
  @override
  Widget build(BuildContext context) => const MealsScreen();
}

class AnnouncementsBranch extends StatelessWidget {
  const AnnouncementsBranch({super.key});
  @override
  Widget build(BuildContext context) => const AnnouncementsScreen();
}