import 'package:famplan/config/supabase.dart';
import 'package:famplan/data/models/task.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class TaskRepository {
  SupabaseClient get _client => SupabaseConfig.client;
  final _uuid = const Uuid();

  Future<List<Task>> fetchTasks(String familyId) async {
    final response = await _client
        .from('tasks')
        .select('*, assignee:profiles!tasks_assignee_id_fkey(*)')
        .eq('family_id', familyId)
        .neq('status', 'archived')
        .order('due_at', ascending: true);

    return (response as List<dynamic>)
        .map((json) => Task.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Stream<List<Task>> watchTasks(String familyId) {
    return _client
        .from('tasks')
        .stream(primaryKey: ['id'])
        .eq('family_id', familyId)
        .map((rows) => rows
            .where((row) => row['status'] != 'archived')
            .map((json) => Task.fromJson(json))
            .toList());
  }

  Future<Task> createTask({
    required String familyId,
    required String title,
    String? notes,
    String? assigneeId,
    DateTime? dueAt,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    final now = DateTime.now().toIso8601String();
    final response = await _client.from('tasks').insert({
      'id': _uuid.v4(),
      'family_id': familyId,
      'created_by': userId,
      'title': title.trim(),
      'notes': notes?.trim(),
      'assignee_id': assigneeId,
      'due_at': dueAt?.toIso8601String(),
      'status': 'pending',
      'created_at': now,
      'updated_at': now,
    }).select().single();

    return Task.fromJson(response);
  }

  Future<Task> completeTask(String taskId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw StateError('Not authenticated');

    final now = DateTime.now().toIso8601String();
    final response = await _client
        .from('tasks')
        .update({
          'status': 'completed',
          'completed_at': now,
          'completed_by': userId,
          'updated_at': now,
        })
        .eq('id', taskId)
        .select()
        .single();

    return Task.fromJson(response);
  }

  Future<void> deleteTask(String taskId) async {
    await _client.from('tasks').delete().eq('id', taskId);
  }
}
