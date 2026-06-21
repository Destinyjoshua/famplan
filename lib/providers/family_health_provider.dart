import 'package:famplan/data/models/family_health.dart';
import 'package:famplan/data/repositories/family_health_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final familyHealthRepositoryProvider =
    Provider<FamilyHealthRepository>((ref) => FamilyHealthRepository());

final familyHealthProvider =
    FutureProvider.family<FamilyHealth, String>((ref, familyId) async {
  return ref.watch(familyHealthRepositoryProvider).fetchHealth(familyId);
});

class FamilyHealthController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> refresh(String familyId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      ref.invalidate(familyHealthProvider(familyId));
    });
  }
}

final familyHealthControllerProvider =
    NotifierProvider<FamilyHealthController, AsyncValue<void>>(
  FamilyHealthController.new,
);