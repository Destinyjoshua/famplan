import 'package:famplan/config/supabase.dart';
import 'package:famplan/core/utils/phone_utils.dart';
import 'package:famplan/data/models/profile.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class OtpSendResult {
  const OtpSendResult({required this.pinId, required this.phone});

  final String pinId;
  final String phone;
}

class AuthRepository {
  SupabaseClient get _client => SupabaseConfig.client;

  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<OtpSendResult> sendOtp({required String phone}) async {
    final normalized = normalizePhone(phone);
    if (normalized == null) {
      throw ArgumentError('Enter a valid Nigerian phone number');
    }

    final response = await _client.functions.invoke(
      'send-otp',
      body: {'phone': normalized},
    );

    final data = _readFunctionData(response.data);
    _throwIfFunctionError(response.status, data);

    final pinId = data['pin_id'] as String?;
    if (pinId == null || pinId.isEmpty) {
      throw const AuthException('Could not send verification code');
    }

    return OtpSendResult(
      pinId: pinId,
      phone: data['phone'] as String? ?? normalized,
    );
  }

  Future<void> verifyOtp({
    required String phone,
    required String pinId,
    required String pin,
  }) async {
    final normalized = normalizePhone(phone);
    if (normalized == null) {
      throw ArgumentError('Enter a valid Nigerian phone number');
    }

    final response = await _client.functions.invoke(
      'verify-otp',
      body: {
        'phone': normalized,
        'pin_id': pinId,
        'pin': pin.trim(),
      },
    );

    final data = _readFunctionData(response.data);
    _throwIfFunctionError(response.status, data);

    final accessToken = data['access_token'] as String?;
    final refreshToken = data['refresh_token'] as String?;

    if (accessToken == null || refreshToken == null) {
      throw const AuthException('Could not sign in after verification');
    }

    await _client.auth.setSession(refreshToken, accessToken: accessToken);
    await _syncProfilePhone(normalized);
  }

  Map<String, dynamic> _readFunctionData(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return {};
  }

  void _throwIfFunctionError(int? status, Map<String, dynamic> data) {
    if (status != null && status >= 400) {
      throw AuthException(data['error']?.toString() ?? 'Request failed');
    }
    if (data['error'] != null) {
      throw AuthException(data['error'].toString());
    }
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