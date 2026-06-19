import 'package:famplan/data/models/profile.dart';

class Task {
  const Task({
    required this.id,
    required this.familyId,
    required this.createdBy,
    required this.title,
    this.notes,
    this.assigneeId,
    this.dueAt,
    required this.status,
    this.completedAt,
    this.completedBy,
    required this.createdAt,
    required this.updatedAt,
    this.assignee,
  });

  final String id;
  final String familyId;
  final String createdBy;
  final String title;
  final String? notes;
  final String? assigneeId;
  final DateTime? dueAt;
  final String status;
  final DateTime? completedAt;
  final String? completedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Profile? assignee;

  bool get isCompleted => status == 'completed';
  bool get isOverdue =>
      !isCompleted && dueAt != null && dueAt!.isBefore(DateTime.now());

  Task copyWith({
    String? status,
    DateTime? completedAt,
    String? completedBy,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id,
      familyId: familyId,
      createdBy: createdBy,
      title: title,
      notes: notes,
      assigneeId: assigneeId,
      dueAt: dueAt,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      completedBy: completedBy ?? this.completedBy,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      assignee: assignee,
    );
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      createdBy: json['created_by'] as String,
      title: json['title'] as String,
      notes: json['notes'] as String?,
      assigneeId: json['assignee_id'] as String?,
      dueAt: json['due_at'] != null
          ? DateTime.parse(json['due_at'] as String)
          : null,
      status: json['status'] as String,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      completedBy: json['completed_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      assignee: json['assignee'] != null
          ? Profile.fromJson(json['assignee'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'family_id': familyId,
        'created_by': createdBy,
        'title': title,
        'notes': notes,
        'assignee_id': assigneeId,
        'due_at': dueAt?.toIso8601String(),
        'status': status,
        'completed_at': completedAt?.toIso8601String(),
        'completed_by': completedBy,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
