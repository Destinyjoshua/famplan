import 'package:famplan/data/models/event.dart';
import 'package:famplan/data/repositories/event_repository.dart';
import 'package:famplan/providers/family_provider.dart';
import 'package:famplan/shared/widgets/empty_state.dart';
import 'package:famplan/shared/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepository();
});

final monthEventsProvider =
    FutureProvider.family<List<Event>, ({String familyId, DateTime month})>(
        (ref, params) async {
  return ref.watch(eventRepositoryProvider).fetchEventsForMonth(
        params.familyId,
        params.month,
      );
});

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final familyAsync = ref.watch(currentFamilyProvider);

    return familyAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (family) {
        if (family == null) {
          return const Scaffold(
            body: EmptyState(icon: Icons.calendar_month, title: 'No family'),
          );
        }

        final eventsAsync = ref.watch(
          monthEventsProvider((familyId: family.id, month: _focusedMonth)),
        );

        return Scaffold(
          appBar: AppBar(
            title: Text(DateFormat('MMMM yyyy').format(_focusedMonth)),
            leading: IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() {
                _focusedMonth = DateTime(
                  _focusedMonth.year,
                  _focusedMonth.month - 1,
                );
              }),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => setState(() {
                  _focusedMonth = DateTime(
                    _focusedMonth.year,
                    _focusedMonth.month + 1,
                  );
                }),
              ),
            ],
          ),
          body: eventsAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (events) {
              final dayEvents = events.where((e) {
                return e.startsAt.year == _selectedDay.year &&
                    e.startsAt.month == _selectedDay.month &&
                    e.startsAt.day == _selectedDay.day;
              }).toList();

              return Column(
                children: [
                  _MonthGrid(
                    month: _focusedMonth,
                    selectedDay: _selectedDay,
                    events: events,
                    onDaySelected: (day) => setState(() => _selectedDay = day),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: dayEvents.isEmpty
                        ? const EmptyState(
                            icon: Icons.event_available,
                            title: 'No events this day',
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: dayEvents.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final event = dayEvents[index];
                              return Card(
                                child: ListTile(
                                  leading: const Icon(Icons.event),
                                  title: Text(event.title),
                                  subtitle: Text(
                                    event.allDay
                                        ? 'All day'
                                        : '${DateFormat('h:mm a').format(event.startsAt)} - ${DateFormat('h:mm a').format(event.endsAt)}',
                                  ),
                                  trailing: event.location != null
                                      ? Tooltip(
                                          message: event.location!,
                                          child: const Icon(Icons.place_outlined),
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showCreateEventDialog(context, family.id),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Future<void> _showCreateEventDialog(BuildContext context, String familyId) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _CreateEventDialog(
        familyId: familyId,
        initialDate: _selectedDay,
      ),
    );

    if (created == true) {
      ref.invalidate(
        monthEventsProvider((familyId: familyId, month: _focusedMonth)),
      );
    }
  }
}

class _CreateEventDialog extends ConsumerStatefulWidget {
  const _CreateEventDialog({
    required this.familyId,
    required this.initialDate,
  });

  final String familyId;
  final DateTime initialDate;

  @override
  ConsumerState<_CreateEventDialog> createState() => _CreateEventDialogState();
}

class _CreateEventDialogState extends ConsumerState<_CreateEventDialog> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  late DateTime _startDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 10, minute: 0);
  bool _allDay = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialDate;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _createEvent() async {
    if (_titleController.text.trim().isEmpty) return;

    final startsAt = _allDay
        ? DateTime(_startDate.year, _startDate.month, _startDate.day)
        : DateTime(
            _startDate.year,
            _startDate.month,
            _startDate.day,
            _startTime.hour,
            _startTime.minute,
          );
    final endsAt = _allDay
        ? DateTime(_startDate.year, _startDate.month, _startDate.day, 23, 59)
        : DateTime(
            _startDate.year,
            _startDate.month,
            _startDate.day,
            _endTime.hour,
            _endTime.minute,
          );

    await ref.read(eventRepositoryProvider).createEvent(
          familyId: widget.familyId,
          title: _titleController.text,
          startsAt: startsAt,
          endsAt: endsAt,
          allDay: _allDay,
          location: _locationController.text.isEmpty
              ? null
              : _locationController.text,
        );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New event'),
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
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('All day'),
              value: _allDay,
              onChanged: (value) => setState(() => _allDay = value),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(DateFormat('MMM d, y').format(_startDate)),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 30)),
                  lastDate: DateTime.now().add(const Duration(days: 730)),
                );
                if (picked != null) setState(() => _startDate = picked);
              },
            ),
            if (!_allDay) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Start: ${_startTime.format(context)}'),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _startTime,
                  );
                  if (picked != null) setState(() => _startTime = picked);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('End: ${_endTime.format(context)}'),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _endTime,
                  );
                  if (picked != null) setState(() => _endTime = picked);
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _createEvent,
          child: const Text('Create'),
        ),
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selectedDay,
    required this.events,
    required this.onDaySelected,
  });

  final DateTime month;
  final DateTime selectedDay;
  final List<Event> events;
  final ValueChanged<DateTime> onDaySelected;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startWeekday = firstDay.weekday;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                .map((d) => SizedBox(
                      width: 36,
                      child: Text(
                        d,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: startWeekday - 1 + daysInMonth,
            itemBuilder: (context, index) {
              if (index < startWeekday - 1) return const SizedBox();

              final day = index - (startWeekday - 1) + 1;
              final date = DateTime(month.year, month.month, day);
              final isSelected = selectedDay.year == date.year &&
                  selectedDay.month == date.month &&
                  selectedDay.day == date.day;
              final hasEvents = events.any((e) =>
                  e.startsAt.year == date.year &&
                  e.startsAt.month == date.month &&
                  e.startsAt.day == date.day);

              return InkWell(
                onTap: () => onDaySelected(date),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$day',
                        style: TextStyle(
                          color: isSelected ? Colors.white : null,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (hasEvents)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.only(top: 2),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).colorScheme.secondary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
