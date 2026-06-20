import 'package:famplan/data/models/profile.dart';
import 'package:famplan/data/repositories/auth_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authRepositoryProvider).currentUser;
});

final profileProvider = FutureProvider<Profile?>((ref) async {
  final authState = ref.watch(authStateProvider);
  if (authState.value?.session == null) return null;
  return ref.watch(authRepositoryProvider).getProfile();
});

class AuthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<OtpSendResult> sendOtp({required String phone}) async {
    state = const AsyncValue.loading();
    late OtpSendResult result;
    state = await AsyncValue.guard(() async {
      result = await ref.read(authRepositoryProvider).sendOtp(phone: phone);
    });
    if (state.hasError) throw state.error!;
    return result;
  }

  Future<void> verifyOtp({
    required String phone,
    required String pinId,
    required String pin,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).verifyOtp(
            phone: phone,
            pinId: pinId,
            pin: pin,
          );
    });
    if (state.hasError) throw state.error!;
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).signOut();
    });
  }

  Future<String?> updateProfile(String displayName) async {
    state = const AsyncValue.loading();
    String? errorMessage;
    state = await AsyncValue.guard(() async {
      await ref.read(authRepositoryProvider).upsertProfile(
            displayName: displayName,
          );
      ref.invalidate(profileProvider);
    });
    if (state.hasError) {
      errorMessage = state.error.toString();
    }
    return errorMessage;
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AsyncValue<void>>(AuthController.new);