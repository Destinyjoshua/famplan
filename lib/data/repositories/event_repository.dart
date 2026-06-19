import 'package:famplan/config/supabase.dart';
import 'package:famplan/data/models/event.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class EventRepository {
  SupabaseClient get _client => SupabaseConfig.client;
  final _uuid = const Uuid();

  Future<List<Event>> fetchEventsForMonth(String familyId, DateTime month) async {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

    final response = await _client
        .from('events')
        .select()
        .eq('family_id', familyId)
        .eq('status', 'active')
        .gte('starts_at', start.toIso8601String())
        .lte('starts_at', end.toIso8601String())
        .order('starts_at');

    return (response as List<dynamic>)
        .map((json) => Event.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<List<Event>> fetchEventsForDay(String familyId, DateTime day) async {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));

    final response = await _client
        .from('events')
        .select()
        .eq('family_id', familyId)
        .eq('status', 'active')
        .gte('starts_at', start.toIso8601String())
        .lt('starts_at', end.toIso8601String())
        .order('starts_at');

    return (response as List<dynamic>)
        .map((json) => Event.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Event> createEvent({
    required String familyId,
    required String title,
    required DateTime startsAt,
    required DateTime endsAt,
    bool allDay = false,
    String? location,
    String? notes,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    final now = DateTime.now().toIso8601String();
    final response = await _client.from('events').insert({
      'id': _uuid.v4(),
      'family_id': familyId,
      'created_by': userId,
      'title': title.trim(),
      'location': location?.trim(),
      'notes': notes?.trim(),
      'starts_at': startsAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
      'all_day': allDay,
      'status': 'active',
      'created_at': now,
      'updated_at': now,
    }).select().single();

    return Event.fromJson(response);
  }

  Future<void> deleteEvent(String eventId) async {
    await _client
        .from('events')
        .update({'status': 'cancelled'})
        .eq('id', eventId);
  }
}
