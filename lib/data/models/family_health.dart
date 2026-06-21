class FamilyHealth {
  const FamilyHealth({
    required this.score,
    required this.label,
    required this.periodDays,
    required this.metrics,
    required this.insights,
  });

  final int score;
  final String label;
  final int periodDays;
  final FamilyHealthMetrics metrics;
  final List<String> insights;

  factory FamilyHealth.fromJson(Map<String, dynamic> json) {
    final rawInsights = json['insights'];
    final insights = <String>[];
    if (rawInsights is List) {
      for (final item in rawInsights) {
        if (item is String) insights.add(item);
      }
    }

    return FamilyHealth(
      score: (json['score'] as num?)?.round() ?? 0,
      label: json['label'] as String? ?? 'Unknown',
      periodDays: (json['period_days'] as num?)?.round() ?? 7,
      metrics: FamilyHealthMetrics.fromJson(
        json['metrics'] as Map<String, dynamic>? ?? {},
      ),
      insights: insights,
    );
  }
}

class FamilyHealthMetrics {
  const FamilyHealthMetrics({
    required this.tasksCreated,
    required this.tasksCompleted,
    required this.tasksOverdue,
    required this.upcomingEvents,
    required this.announcements,
    required this.mealsPlanned,
    required this.mealsTotal,
    required this.activeMembers,
    required this.engagedMembers,
    required this.taskScore,
    required this.calendarScore,
    required this.communicationScore,
    required this.mealScore,
    required this.engagementScore,
  });

  final int tasksCreated;
  final int tasksCompleted;
  final int tasksOverdue;
  final int upcomingEvents;
  final int announcements;
  final int mealsPlanned;
  final int mealsTotal;
  final int activeMembers;
  final int engagedMembers;
  final int taskScore;
  final int calendarScore;
  final int communicationScore;
  final int mealScore;
  final int engagementScore;

  factory FamilyHealthMetrics.fromJson(Map<String, dynamic> json) {
    int readInt(String key) => (json[key] as num?)?.round() ?? 0;

    return FamilyHealthMetrics(
      tasksCreated: readInt('tasks_created'),
      tasksCompleted: readInt('tasks_completed'),
      tasksOverdue: readInt('tasks_overdue'),
      upcomingEvents: readInt('upcoming_events'),
      announcements: readInt('announcements'),
      mealsPlanned: readInt('meals_planned'),
      mealsTotal: readInt('meals_total'),
      activeMembers: readInt('active_members'),
      engagedMembers: readInt('engaged_members'),
      taskScore: readInt('task_score'),
      calendarScore: readInt('calendar_score'),
      communicationScore: readInt('communication_score'),
      mealScore: readInt('meal_score'),
      engagementScore: readInt('engagement_score'),
    );
  }
}