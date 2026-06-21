import 'package:famplan/config/supabase.dart';
import 'package:famplan/data/models/family_health.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyHealthRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<FamilyHealth> fetchHealth(String familyId) async {
    try {
      final response = await _client.rpc(
        'get_family_health',
        params: {'p_family_id': familyId},
      );

      if (response is Map<String, dynamic>) {
        return FamilyHealth.fromJson(response);
      }
    } catch (_) {
      // Fall back to client-side estimate when RPC is unavailable.
    }

    return _fetchHealthFallback(familyId);
  }

  Future<FamilyHealth> _fetchHealthFallback(String familyId) async {
    final windowStart = DateTime.now().subtract(const Duration(days: 7));

    final tasks = await _client
        .from('tasks')
        .select('status, due_at, created_at, completed_at')
        .eq('family_id', familyId);

    final events = await _client
        .from('events')
        .select('id')
        .eq('family_id', familyId)
        .eq('status', 'active')
        .gte('starts_at', DateTime.now().toIso8601String())
        .lt('starts_at', DateTime.now().add(const Duration(days: 7)).toIso8601String());

    final announcements = await _client
        .from('announcements')
        .select('id')
        .eq('family_id', familyId)
        .gte('created_at', windowStart.toIso8601String());

    final members = await _client
        .from('family_members')
        .select('id')
        .eq('family_id', familyId)
        .eq('status', 'active');

    final taskRows = (tasks as List<dynamic>).cast<Map<String, dynamic>>();
    final created = taskRows
        .where((t) => DateTime.parse(t['created_at'] as String).isAfter(windowStart))
        .length;
    final completed = taskRows
        .where((t) =>
            t['status'] == 'completed' &&
            t['completed_at'] != null &&
            DateTime.parse(t['completed_at'] as String).isAfter(windowStart))
        .length;
    final overdue = taskRows
        .where((t) =>
            t['status'] == 'pending' &&
            t['due_at'] != null &&
            DateTime.parse(t['due_at'] as String).isBefore(DateTime.now()))
        .length;

    final taskScore = created == 0 && completed == 0
        ? 55
        : ((completed / (created == 0 ? 1 : created)) * 100).round().clamp(0, 100);
    final calendarScore = (events as List).isEmpty ? 35 : 75;
    final commScore = (announcements as List).isEmpty ? 40 : 70;
    final engagementScore = (members as List).length <= 1 ? 60 : 55;
    final mealScore = 45;

    final overall = ((taskScore * 0.35) +
            (calendarScore * 0.15) +
            (commScore * 0.15) +
            (mealScore * 0.15) +
            (engagementScore * 0.20))
        .round();

    final label = overall >= 80
        ? 'Thriving'
        : overall >= 60
            ? 'Healthy'
            : overall >= 40
                ? 'Fair'
                : 'Needs attention';

    final insights = <String>[];
    if (overdue > 0) {
      insights.add('$overdue overdue task${overdue == 1 ? '' : 's'} — tackle the oldest one first.');
    }
    if (insights.isEmpty) {
      insights.add('Keep coordinating — run the latest app update for full health insights.');
    }

    return FamilyHealth(
      score: overall,
      label: label,
      periodDays: 7,
      metrics: FamilyHealthMetrics(
        tasksCreated: created,
        tasksCompleted: completed,
        tasksOverdue: overdue,
        upcomingEvents: (events as List).length,
        announcements: (announcements as List).length,
        mealsPlanned: 0,
        mealsTotal: 0,
        activeMembers: (members as List).length,
        engagedMembers: 0,
        taskScore: taskScore,
        calendarScore: calendarScore,
        communicationScore: commScore,
        mealScore: mealScore,
        engagementScore: engagementScore,
      ),
      insights: insights,
    );
  }
}