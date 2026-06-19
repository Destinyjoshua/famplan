class Event {
  const Event({
    required this.id,
    required this.familyId,
    required this.createdBy,
    required this.title,
    this.location,
    this.notes,
    required this.startsAt,
    required this.endsAt,
    required this.allDay,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String familyId;
  final String createdBy;
  final String title;
  final String? location;
  final String? notes;
  final DateTime startsAt;
  final DateTime endsAt;
  final bool allDay;
  final String status;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      createdBy: json['created_by'] as String,
      title: json['title'] as String,
      location: json['location'] as String?,
      notes: json['notes'] as String?,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      allDay: json['all_day'] as bool? ?? false,
      status: json['status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'family_id': familyId,
        'created_by': createdBy,
        'title': title,
        'location': location,
        'notes': notes,
        'starts_at': startsAt.toIso8601String(),
        'ends_at': endsAt.toIso8601String(),
        'all_day': allDay,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
