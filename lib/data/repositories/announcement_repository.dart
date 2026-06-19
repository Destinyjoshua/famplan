import 'package:famplan/config/supabase.dart';
import 'package:famplan/data/models/announcement.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class AnnouncementRepository {
  SupabaseClient get _client => SupabaseConfig.client;
  final _uuid = const Uuid();

  Future<List<Announcement>> fetchAnnouncements(String familyId) async {
    final response = await _client
        .from('announcements')
        .select(
          '*, author:profiles!announcements_author_id_fkey(*), '
          'announcement_comments(*, author:profiles!announcement_comments_author_id_fkey(*))',
        )
        .eq('family_id', familyId)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false);

    return (response as List<dynamic>)
        .map((json) => Announcement.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Announcement> createAnnouncement({
    required String familyId,
    required String body,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    final now = DateTime.now().toIso8601String();
    final response = await _client.from('announcements').insert({
      'id': _uuid.v4(),
      'family_id': familyId,
      'author_id': userId,
      'body': body.trim(),
      'is_pinned': false,
      'created_at': now,
      'updated_at': now,
    }).select().single();

    return Announcement.fromJson(response);
  }

  Future<Announcement> togglePin({
    required String announcementId,
    required bool isPinned,
  }) async {
    final response = await _client
        .from('announcements')
        .update({
          'is_pinned': isPinned,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', announcementId)
        .select()
        .single();

    return Announcement.fromJson(response);
  }

  Future<AnnouncementComment> addComment({
    required String announcementId,
    required String body,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    final response = await _client.from('announcement_comments').insert({
      'id': _uuid.v4(),
      'announcement_id': announcementId,
      'author_id': userId,
      'body': body.trim(),
      'created_at': DateTime.now().toIso8601String(),
    }).select().single();

    return AnnouncementComment.fromJson(response);
  }
}
