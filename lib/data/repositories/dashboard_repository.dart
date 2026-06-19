import 'package:famplan/config/supabase.dart';
import 'package:famplan/data/models/announcement.dart';
import 'package:famplan/data/models/dashboard.dart';
import 'package:famplan/data/models/event.dart';
import 'package:famplan/data/models/meal.dart';
import 'package:famplan/data/models/task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<Dashboard> fetchDashboard({
    required String familyId,
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final dateStr = targetDate.toIso8601String().split('T').first;

    try {
      final response = await _client.rpc(
        'get_dashboard',
        params: {
          'p_family_id': familyId,
          'p_date': dateStr,
        },
      );

      if (response is Map<String, dynamic>) {
        return Dashboard.fromJson(response);
      }
    } catch (_) {
      // Fall back to individual queries if RPC is unavailable.
    }

    return _fetchDashboardFallback(familyId, targetDate);
  }

  Future<Dashboard> _fetchDashboardFallback(
    String familyId,
    DateTime date,
  ) async {
    final dayStart = DateTime(date.year, date.month, date.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final userId = _client.auth.currentUser?.id;
    final dayOfWeek = date.weekday - 1;

    final tasksResponse = await _client
        .from('tasks')
        .select()
        .eq('family_id', familyId)
        .eq('status', 'pending')
        .or('due_at.is.null,due_at.lte.${dayEnd.toIso8601String()}')
        .order('due_at')
        .limit(5);

    final eventsResponse = await _client
        .from('events')
        .select()
        .eq('family_id', familyId)
        .eq('status', 'active')
        .gte('starts_at', dayStart.toIso8601String())
        .lt('starts_at', dayEnd.toIso8601String())
        .order('starts_at');

    final announcementsResponse = await _client
        .from('announcements')
        .select()
        .eq('family_id', familyId)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false)
        .limit(3);

    final weekMonday =
        dayStart.subtract(Duration(days: dayStart.weekday - 1));
    final weekDate = weekMonday.toIso8601String().split('T').first;

    final mealPlanResponse = await _client
        .from('meal_plans')
        .select('meal_slots(*)')
        .eq('family_id', familyId)
        .eq('week_start_date', weekDate)
        .maybeSingle();

    final meals = <MealSlot>[];
    if (mealPlanResponse != null) {
      final slots = mealPlanResponse['meal_slots'] as List<dynamic>? ?? [];
      meals.addAll(
        slots
            .where((s) => (s as Map<String, dynamic>)['day_of_week'] == dayOfWeek)
            .map((s) => MealSlot.fromJson(s as Map<String, dynamic>)),
      );
    }

    final tasks = (tasksResponse as List<dynamic>)
        .map((e) => Task.fromJson(e as Map<String, dynamic>))
        .where((t) => userId == null || t.assigneeId == null || t.assigneeId == userId)
        .take(3)
        .toList();

    return Dashboard(
      date: dayStart,
      tasks: tasks,
      events: (eventsResponse as List<dynamic>)
          .map((e) => Event.fromJson(e as Map<String, dynamic>))
          .toList(),
      meals: meals,
      announcements: (announcementsResponse as List<dynamic>)
          .map((e) => Announcement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
