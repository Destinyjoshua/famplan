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
  }
}

final familyControllerProvider =
    NotifierProvider<FamilyController, AsyncValue<Family?>>(FamilyController.new);
