import 'package:famplan/config/supabase.dart';
import 'package:famplan/data/models/family.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FamilyRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  Future<Family?> getCurrentFamily() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await _client
        .from('family_members')
        .select('families(*)')
        .eq('user_id', userId)
        .eq('status', 'active')
        .maybeSingle();

    if (response == null || response['families'] == null) return null;
    return Family.fromJson(response['families'] as Map<String, dynamic>);
  }

  Future<List<FamilyMember>> getMembers(String familyId) async {
    final response = await _client
        .from('family_members')
        .select('*, profiles(*)')
        .eq('family_id', familyId)
        .eq('status', 'active')
        .order('joined_at');

    return (response as List<dynamic>)
        .map((json) => FamilyMember.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<Family> createFamily({required String name}) async {
    final response = await _client.rpc(
      'create_family',
      params: {'family_name': name.trim()},
    );

    if (response is Map<String, dynamic>) {
      return Family.fromJson(response);
    }
    throw StateError('Unexpected create_family response');
  }

  Future<Family> joinFamily({required String inviteCode}) async {
    final response = await _client.rpc(
      'join_family',
      params: {'invite_code': inviteCode.trim().toUpperCase()},
    );

    if (response is Map<String, dynamic>) {
      return Family.fromJson(response);
    }
    throw StateError('Unexpected join_family response');
  }
}
