import 'package:famplan/data/models/family.dart';
import 'package:famplan/data/models/meal.dart';
import 'package:famplan/data/repositories/meal_repository.dart';
import 'package:famplan/providers/family_provider.dart';
import 'package:famplan/shared/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final mealRepositoryProvider = Provider<MealRepository>((ref) {
  return MealRepository();
});

final mealPlanProvider =
    FutureProvider.family<MealPlan, ({String familyId, DateTime week})>(
        (ref, params) async {
  return ref.watch(mealRepositoryProvider).getOrCreateMealPlan(
        params.familyId,
        params.week,
      );
});

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _mealTypes = ['breakfast', 'lunch', 'dinner'];

class MealsScreen extends ConsumerStatefulWidget {
  const MealsScreen({super.key});

  @override
  ConsumerState<MealsScreen> createState() => _MealsScreenState();
}

class _MealsScreenState extends ConsumerState<MealsScreen> {
  DateTime _weekStart = DateTime.now();

  DateTime get _monday {
    final weekday = _weekStart.weekday;
    return DateTime(_weekStart.year, _weekStart.month, _weekStart.day - (weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(currentFamilyProvider);

    return familyAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (family) {
        if (family == null) {
          return const Scaffold(body: Center(child: Text('No family')));
        }

        final planAsync = ref.watch(
          mealPlanProvider((familyId: family.id, week: _monday)),
        );
        final membersAsync = ref.watch(familyMembersProvider(family.id));

        return Scaffold(
          appBar: AppBar(
            title: const Text('Meal Planner'),
            actions: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => setState(() {
                  _weekStart = _monday.subtract(const Duration(days: 7));
                }),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() {
                  _weekStart = _monday.add(const Duration(days: 7));
                }),
              ),
              IconButton(
                icon: const Icon(Icons.shopping_cart_outlined),
                tooltip: 'Grocery list',
                onPressed: planAsync.hasValue
                    ? () => _shareGroceryList(planAsync.value!)
                    : null,
              ),
            ],
          ),
          body: planAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (plan) {
              final members = membersAsync.value ?? [];

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Week of ${DateFormat('MMM d').format(_monday)}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(7, (dayIndex) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _days[dayIndex],
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 8),
                            ..._mealTypes.map((type) {
                              final slot = plan.slots.cast<MealSlot?>().firstWhere(
                                    (s) =>
                                        s!.dayOfWeek == dayIndex &&
                                        s.mealType == type,
                                    orElse: () => null,
                                  );

                              return _MealSlotRow(
                                mealType: type,
                                slot: slot,
                                members: members,
                                onTap: () => _editSlot(
                                  family: family,
                                  plan: plan,
                                  dayIndex: dayIndex,
                                  mealType: type,
                                  slot: slot,
                                  members: members,
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _editSlot({
    required Family family,
    required MealPlan plan,
    required int dayIndex,
    required String mealType,
    required MealSlot? slot,
    required List<FamilyMember> members,
  }) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => _EditMealSlotDialog(
        family: family,
        plan: plan,
        dayIndex: dayIndex,
        mealType: mealType,
        slot: slot,
        members: members,
      ),
    );

    if (saved == true) {
      ref.invalidate(
        mealPlanProvider((familyId: family.id, week: _monday)),
      );
    }
  }

  Future<void> _shareGroceryList(MealPlan plan) async {
    final items = await ref
        .read(mealRepositoryProvider)
        .generateGroceryList(plan.id);

    if (!mounted) return;

    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No ingredients to share yet')),
      );
      return;
    }

    final text = items.map((i) => '- ${i.displayText}').join('\n');

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Grocery List'),
        content: SingleChildScrollView(child: Text(text)),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: text));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

class _MealSlotRow extends StatelessWidget {
  const _MealSlotRow({
    required this.mealType,
    required this.slot,
    required this.members,
    required this.onTap,
  });

  final String mealType;
  final MealSlot? slot;
  final List<FamilyMember> members;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cookName = slot?.cookId != null
        ? members
            .where((m) => m.userId == slot!.cookId)
            .map((m) => m.profile?.displayName ?? 'Member')
            .firstOrNull
        : null;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Icon(
        mealType == 'breakfast'
            ? Icons.free_breakfast
            : mealType == 'lunch'
                ? Icons.lunch_dining
                : Icons.dinner_dining,
        size: 20,
      ),
      title: Text(
        slot?.mealName ?? 'Tap to add $mealType',
        style: TextStyle(
          color: slot?.mealName == null
              ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
              : null,
        ),
      ),
      subtitle: cookName != null ? Text('Cook: $cookName') : null,
      trailing: const Icon(Icons.edit_outlined, size: 16),
      onTap: onTap,
    );
  }
}

class _EditMealSlotDialog extends ConsumerStatefulWidget {
  const _EditMealSlotDialog({
    required this.family,
    required this.plan,
    required this.dayIndex,
    required this.mealType,
    required this.slot,
    required this.members,
  });

  final Family family;
  final MealPlan plan;
  final int dayIndex;
  final String mealType;
  final MealSlot? slot;
  final List<FamilyMember> members;

  @override
  ConsumerState<_EditMealSlotDialog> createState() => _EditMealSlotDialogState();
}

class _EditMealSlotDialogState extends ConsumerState<_EditMealSlotDialog> {
  late final TextEditingController _nameController;
  String? _cookId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.slot?.mealName ?? '');
    _cookId = widget.slot?.cookId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await ref.read(mealRepositoryProvider).upsertMealSlot(
          mealPlanId: widget.plan.id,
          familyId: widget.family.id,
          dayOfWeek: widget.dayIndex,
          mealType: widget.mealType,
          mealName: _nameController.text.trim().isEmpty
              ? null
              : _nameController.text.trim(),
          cookId: _cookId,
        );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final title =
        '${_days[widget.dayIndex]} ${widget.mealType[0].toUpperCase()}${widget.mealType.substring(1)}';

    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Meal name'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            value: _cookId,
            decoration: const InputDecoration(labelText: 'Cook'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Unassigned')),
              ...widget.members.map(
                (m) => DropdownMenuItem(
                  value: m.userId,
                  child: Text(m.profile?.displayName ?? 'Member'),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _cookId = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
