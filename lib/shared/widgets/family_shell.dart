import 'package:famplan/features/announcements/presentation/announcements_screen.dart';
import 'package:famplan/features/calendar/presentation/calendar_screen.dart';
import 'package:famplan/features/dashboard/presentation/dashboard_screen.dart';
import 'package:famplan/features/meals/presentation/meals_screen.dart';
import 'package:famplan/features/tasks/presentation/tasks_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class FamilyShell extends StatelessWidget {
  const FamilyShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (icon: Icons.dashboard_outlined, selectedIcon: Icons.dashboard, label: 'Home'),
    (icon: Icons.calendar_month_outlined, selectedIcon: Icons.calendar_month, label: 'Calendar'),
    (icon: Icons.task_alt_outlined, selectedIcon: Icons.task_alt, label: 'Tasks'),
    (icon: Icons.restaurant_menu_outlined, selectedIcon: Icons.restaurant_menu, label: 'Meals'),
    (icon: Icons.campaign_outlined, selectedIcon: Icons.campaign, label: 'News'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        elevation: 8,
        shadowColor: Colors.black26,
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == navigationShell.currentIndex,
          );
        },
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

class FamilyShellBranch extends StatelessWidget {
  const FamilyShellBranch({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

// Tab screens for shell branches
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
