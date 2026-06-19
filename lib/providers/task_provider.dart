import 'package:famplan/data/models/task.dart';
import 'package:famplan/data/repositories/task_repository.dart';
import 'package:famplan/providers/auth_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum TaskFilter { all, mine, overdue }

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

final tasksStreamProvider =
    StreamProvider.family<List<Task>, String>((ref, familyId) {
  return ref.watch(taskRepositoryProvider).watchTasks(familyId);
});

class TaskFilterNotifier extends Notifier<TaskFilter> {
  @override
  TaskFilter build() => TaskFilter.all;

  void setFilter(TaskFilter filter) => state = filter;
}

final taskFilterProvider =
    NotifierProvider<TaskFilterNotifier, TaskFilter>(TaskFilterNotifier.new);

final filteredTasksProvider =
    Provider.family<AsyncValue<List<Task>>, String>((ref, familyId) {
  final tasksAsync = ref.watch(tasksStreamProvider(familyId));
  final filter = ref.watch(taskFilterProvider);
  final userId = ref.watch(currentUserProvider)?.id;

  return tasksAsync.whenData((tasks) {
    switch (filter) {
      case TaskFilter.mine:
        return tasks.where((t) => t.assigneeId == userId).toList();
      case TaskFilter.overdue:
        return tasks.where((t) => t.isOverdue).toList();
      case TaskFilter.all:
        return tasks;
    }
  });
});

class TaskController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> createTask({
    required String familyId,
    required String title,
    String? notes,
    String? assigneeId,
    DateTime? dueAt,
  }) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(taskRepositoryProvider).createTask(
            familyId: familyId,
            title: title,
            notes: notes,
            assigneeId: assigneeId,
            dueAt: dueAt,
          );
    });
  }

  Future<void> completeTask(String taskId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(taskRepositoryProvider).completeTask(taskId);
    });
  }

  Future<void> deleteTask(String taskId) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await ref.read(taskRepositoryProvider).deleteTask(taskId);
    });
  }
}

final taskControllerProvider =
    NotifierProvider<TaskController, AsyncValue<void>>(TaskController.new);
