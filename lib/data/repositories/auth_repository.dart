import 'package:famplan/config/supabase.dart';
import 'package:famplan/core/utils/phone_utils.dart';
import 'package:famplan/data/models/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signUpWithPhone({
    required String phone,
    required String password,
  }) async {
    final normalized = normalizePhone(phone);
    if (normalized == null) {
      throw ArgumentError('Enter a valid Nigerian phone number');
    }

    final email = phoneToAuthEmail(normalized);

    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'phone': normalized,
        'display_name': normalized,
      },
    );

    if (response.user == null) {
      throw const AuthException('Could not create account');
    }

    await _syncProfilePhone(normalized);
  }

  Future<void> signInWithPhone({
    required String phone,
    required String password,
  }) async {
    final normalized = normalizePhone(phone);
    if (normalized == null) {
      throw ArgumentError('Enter a valid Nigerian phone number');
    }

    final email = phoneToAuthEmail(normalized);

    await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );

    await _syncProfilePhone(normalized);
  }

  Future<void> _syncProfilePhone(String phone) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client.from('profiles').update({
      'phone': phone,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<Profile?> getProfile() async {
    final user = currentUser;
    if (user == null) return null;

    final response = await _client
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    if (response == null) return null;
    return Profile.fromJson(response);
  }

  Future<Profile> upsertProfile({
    required String displayName,
    String? phone,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw StateError('Not authenticated');
    }

    final payload = <String, dynamic>{
      'display_name': displayName.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (phone != null) {
      payload['phone'] = phone;
    }

    final response = await _client
        .from('profiles')
        .update(payload)
        .eq('id', user.id)
        .select()
        .single();

    return Profile.fromJson(response);
  }
}