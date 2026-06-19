import 'package:famplan/data/models/profile.dart';

class AnnouncementComment {
  const AnnouncementComment({
    required this.id,
    required this.announcementId,
    required this.authorId,
    required this.body,
    required this.createdAt,
    this.author,
  });

  final String id;
  final String announcementId;
  final String authorId;
  final String body;
  final DateTime createdAt;
  final Profile? author;

  factory AnnouncementComment.fromJson(Map<String, dynamic> json) {
    return AnnouncementComment(
      id: json['id'] as String,
      announcementId: json['announcement_id'] as String,
      authorId: json['author_id'] as String,
      body: json['body'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      author: json['author'] != null
          ? Profile.fromJson(json['author'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'announcement_id': announcementId,
        'author_id': authorId,
        'body': body,
        'created_at': createdAt.toIso8601String(),
      };
}

class Announcement {
  const Announcement({
    required this.id,
    required this.familyId,
    required this.authorId,
    required this.body,
    this.photoUrl,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
    this.author,
    this.comments = const [],
  });

  final String id;
  final String familyId;
  final String authorId;
  final String body;
  final String? photoUrl;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Profile? author;
  final List<AnnouncementComment> comments;

  Announcement copyWith({bool? isPinned}) {
    return Announcement(
      id: id,
      familyId: familyId,
      authorId: authorId,
      body: body,
      photoUrl: photoUrl,
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt,
      updatedAt: updatedAt,
      author: author,
      comments: comments,
    );
  }

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] as String,
      familyId: json['family_id'] as String,
      authorId: json['author_id'] as String,
      body: json['body'] as String,
      photoUrl: json['photo_url'] as String?,
      isPinned: json['is_pinned'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      author: json['author'] != null
          ? Profile.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      comments: (json['announcement_comments'] as List<dynamic>?)
              ?.map((e) =>
                  AnnouncementComment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'family_id': familyId,
        'author_id': authorId,
        'body': body,
        'photo_url': photoUrl,
        'is_pinned': isPinned,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };
}
