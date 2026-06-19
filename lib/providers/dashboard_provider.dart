import 'package:famplan/data/models/dashboard.dart';
import 'package:famplan/data/repositories/dashboard_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository();
});

final dashboardProvider =
    FutureProvider.family<Dashboard, String>((ref, familyId) async {
  return ref.watch(dashboardRepositoryProvider).fetchDashboard(
        familyId: familyId,
      );
});

class DashboardController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> refresh(String familyId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      ref.invalidate(dashboardProvider(familyId));
      await ref.read(dashboardProvider(familyId).future);
    });
  }
}

final dashboardControllerProvider =
    NotifierProvider<DashboardController, AsyncValue<void>>(
  DashboardController.new,
);
