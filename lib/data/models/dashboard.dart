import 'package:famplan/data/models/announcement.dart';
import 'package:famplan/data/models/event.dart';
import 'package:famplan/data/models/meal.dart';
import 'package:famplan/data/models/task.dart';

class Dashboard {
  const Dashboard({
    required this.date,
    required this.tasks,
    required this.events,
    required this.meals,
    required this.announcements,
  });

  final DateTime date;
  final List<Task> tasks;
  final List<Event> events;
  final List<MealSlot> meals;
  final List<Announcement> announcements;

  factory Dashboard.fromJson(Map<String, dynamic> json) {
    return Dashboard(
      date: DateTime.parse(json['date'] as String? ?? DateTime.now().toIso8601String()),
      tasks: (json['tasks'] as List<dynamic>?)
              ?.map((e) => Task.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      events: (json['events'] as List<dynamic>?)
              ?.map((e) => Event.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      meals: (json['meals'] as List<dynamic>?)
              ?.map((e) => MealSlot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      announcements: (json['announcements'] as List<dynamic>?)
              ?.map((e) => Announcement.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'tasks': tasks.map((e) => e.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
        'meals': meals.map((e) => e.toJson()).toList(),
        'announcements': announcements.map((e) => e.toJson()).toList(),
      };
}
