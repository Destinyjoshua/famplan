import 'package:famplan/data/models/family.dart';
import 'package:famplan/data/repositories/family_repository.dart';
import 'package:famplan/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  return FamilyRepository();
});

final currentFamilyProvider = FutureProvider<Family?>((ref) async {
  final authState = ref.watch(authStateProvider);
  if (authState.value?.session == null) return null;
  return ref.watch(familyRepositoryProvider).getCurrentFamily();
});

final familyMembersProvider =
    FutureProvider.family<List<FamilyMember>, String>((ref, familyId) async {
  return ref.watch(familyRepositoryProvider).getMembers(familyId);
});

final currentFamilyMembershipProvider =
    FutureProvider<FamilyMember?>((ref) async {
  final family = await ref.watch(currentFamilyProvider.future);
  if (family == null) return null;
  return ref.watch(familyRepositoryProvider).getCurrentMembership(family.id);
});

class FamilyController extends Notifier<AsyncValue<Family?>> {
  @override
  AsyncValue<Family?> build() => const AsyncValue.data(null);

  Future<Family> createFamily(String name) async {
    state = const AsyncValue.loading();
    late Family family;
    state = await AsyncValue.guard(() async {
      family = await ref.read(familyRepositoryProvider).createFamily(name: name);
      return family;
    });
    ref.invalidate(currentFamilyProvider);
    return family;
  }

  Future<Family> joinFamily(String code) async {
    state = const AsyncValue.loading();
    late Family family;
    state = await AsyncValue.guard(() async {
      family = await ref.read(familyRepositoryProvider).joinFamily(
            inviteCode: code,
          );
      return family;
    });
    ref.invalidate(currentFamilyProvider);
    return family;
  }

  void refresh() {
    ref.invalidate(currentFamilyProvider);
    ref.invalidate(currentFamilyMembershipProvider);
  }

  void _invalidateFamily(String familyId) {
    ref.invalidate(currentFamilyProvider);
    ref.invalidate(currentFamilyMembershipProvider);
    ref.invalidate(familyMembersProvider(familyId));
  }

  Future<Family> updateFamilyName({
    required String familyId,
    required String name,
  }) async {
    final family = await ref.read(familyRepositoryProvider).updateFamilyName(
          familyId: familyId,
          name: name,
        );
    _invalidateFamily(familyId);
    return family;
  }

  Future<Family> regenerateInviteCode(String familyId) async {
    final family =
        await ref.read(familyRepositoryProvider).regenerateInviteCode(familyId);
    _invalidateFamily(familyId);
    return family;
  }

  Future<void> updateMemberRole({
    required String familyId,
    required String userId,
    required String role,
  }) async {
    await ref.read(familyRepositoryProvider).updateMemberRole(
          familyId: familyId,
          userId: userId,
          role: role,
        );
    _invalidateFamily(familyId);
  }

  Future<void> removeMember({
    required String familyId,
    required String userId,
  }) async {
    await ref.read(familyRepositoryProvider).removeMember(
          familyId: familyId,
          userId: userId,
        );
    _invalidateFamily(familyId);
  }

  Future<void> leaveFamily(String familyId) async {
    await ref.read(familyRepositoryProvider).leaveFamily(familyId);
    _invalidateFamily(familyId);
  }
}

final familyControllerProvider =
    NotifierProvider<FamilyController, AsyncValue<Family?>>(FamilyController.new);
