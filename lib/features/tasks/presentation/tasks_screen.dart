import 'package:famplan/core/theme/app_theme.dart';
import 'package:famplan/data/models/family.dart';
import 'package:famplan/data/models/task.dart';
import 'package:famplan/providers/family_provider.dart';
import 'package:famplan/providers/task_provider.dart';
import 'package:famplan/shared/widgets/empty_state.dart';
import 'package:famplan/shared/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(currentFamilyProvider);

    return familyAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (family) {
        if (family == null) {
          return const Scaffold(
            body: EmptyState(icon: Icons.task_alt, title: 'No family'),
          );
        }

        final tasksAsync = ref.watch(filteredTasksProvider(family.id));
        final filter = ref.watch(taskFilterProvider);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Tasks'),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: SegmentedButton<TaskFilter>(
                  segments: const [
                    ButtonSegment(value: TaskFilter.all, label: Text('All')),
                    ButtonSegment(value: TaskFilter.mine, label: Text('Mine')),
                    ButtonSegment(
                      value: TaskFilter.overdue,
                      label: Text('Overdue'),
                    ),
                  ],
                  selected: {filter},
                  onSelectionChanged: (value) {
                    ref
                        .read(taskFilterProvider.notifier)
                        .setFilter(value.first);
                  },
                ),
              ),
            ),
          ),
          body: tasksAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (tasks) {
              if (tasks.isEmpty) {
                return EmptyState(
                  icon: Icons.task_alt,
                  title: 'No tasks yet',
                  subtitle: 'Create a task to get started',
                  actionLabel: 'Add task',
                  onAction: () => _showCreateTaskDialog(context, ref, family),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return _TaskCard(task: task, familyId: family.id);
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showCreateTaskDialog(context, ref, family),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Future<void> _showCreateTaskDialog(
    BuildContext context,
    WidgetRef ref,
    Family family,
  ) async {
    final members = await ref.read(familyMembersProvider(family.id).future);

    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => _CreateTaskDialog(
        family: family,
        members: members,
      ),
    );
  }
}

class _CreateTaskDialog extends ConsumerStatefulWidget {
  const _CreateTaskDialog({
    required this.family,
    required this.members,
  });

  final Family family;
  final List<FamilyMember> members;

  @override
  ConsumerState<_CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends ConsumerState<_CreateTaskDialog> {
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _dueDate;
  String? _assigneeId;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _createTask() async {
    if (_titleController.text.trim().isEmpty) return;

    await ref.read(taskControllerProvider.notifier).createTask(
          familyId: widget.family.id,
          title: _titleController.text,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          assigneeId: _assigneeId,
          dueAt: _dueDate,
        );

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New task'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(labelText: 'Notes (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _dueDate == null
                    ? 'Set due date'
                    : DateFormat('MMM d, y').format(_dueDate!),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _dueDate = picked);
              },
            ),
            DropdownButtonFormField<String?>(
              value: _assigneeId,
              decoration: const InputDecoration(labelText: 'Assign to'),
              items: [
                const DropdownMenuItem(value: null, child: Text('Family')),
                ...widget.members.map(
                  (m) => DropdownMenuItem(
                    value: m.userId,
                    child: Text(m.profile?.displayName ?? 'Member'),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => _assigneeId = value),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _createTask,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _TaskCard extends ConsumerWidget {
  const _TaskCard({required this.task, required this.familyId});

  final Task task;
  final String familyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(task.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.error,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Delete task?'),
                content: Text('Remove "${task.title}" from your list?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) {
        ref.read(taskControllerProvider.notifier).deleteTask(task.id);
      },
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: task.isCompleted,
                onChanged: task.isCompleted
                    ? null
                    : (_) => ref
                        .read(taskControllerProvider.notifier)
                        .completeTask(task.id),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 10),
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            decoration: task.isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                            color: task.isOverdue
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                    ),
                    if (task.notes != null && task.notes!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.notes!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (task.dueAt != null)
                          _MetaChip(
                            icon: Icons.calendar_today,
                            label: DateFormat('MMM d').format(task.dueAt!),
                            color: task.isOverdue
                                ? Theme.of(context).colorScheme.error
                                : AppTheme.teal,
                          ),
                        if (task.assignee != null)
                          _MetaChip(
                            icon: Icons.person_outline,
                            label: task.assignee!.displayName,
                            color: AppTheme.violet,
                          ),
                        if (task.isOverdue)
                          _MetaChip(
                            icon: Icons.warning_amber_rounded,
                            label: 'Overdue',
                            color: Theme.of(context).colorScheme.error,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 14, color: color),
      label: Text(label),
      backgroundColor: color.withValues(alpha: 0.1),
      labelStyle: TextStyle(color: color, fontSize: 12),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
