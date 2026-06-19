import 'package:famplan/data/models/announcement.dart';
import 'package:famplan/data/repositories/announcement_repository.dart';
import 'package:famplan/providers/family_provider.dart';
import 'package:famplan/shared/widgets/empty_state.dart';
import 'package:famplan/shared/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

final announcementRepositoryProvider = Provider<AnnouncementRepository>((ref) {
  return AnnouncementRepository();
});

final announcementsProvider =
    FutureProvider.family<List<Announcement>, String>((ref, familyId) async {
  return ref.watch(announcementRepositoryProvider).fetchAnnouncements(familyId);
});

class AnnouncementsScreen extends ConsumerWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(currentFamilyProvider);

    return familyAsync.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
      data: (family) {
        if (family == null) {
          return const Scaffold(
            body: EmptyState(icon: Icons.campaign, title: 'No family'),
          );
        }

        final announcementsAsync = ref.watch(announcementsProvider(family.id));

        return Scaffold(
          appBar: AppBar(title: const Text('Announcements')),
          body: announcementsAsync.when(
            loading: () => const LoadingView(),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (announcements) {
              if (announcements.isEmpty) {
                return EmptyState(
                  icon: Icons.campaign_outlined,
                  title: 'No announcements yet',
                  subtitle: 'Share updates with your family',
                  actionLabel: 'Post update',
                  onAction: () => _showCreateDialog(context, ref, family.id),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(announcementsProvider(family.id));
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: announcements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _AnnouncementCard(
                      announcement: announcements[index],
                      familyId: family.id,
                    );
                  },
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showCreateDialog(context, ref, family.id),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Future<void> _showCreateDialog(
    BuildContext context,
    WidgetRef ref,
    String familyId,
  ) async {
    final posted = await showDialog<bool>(
      context: context,
      builder: (context) => _CreateAnnouncementDialog(familyId: familyId),
    );

    if (posted == true) {
      ref.invalidate(announcementsProvider(familyId));
    }
  }
}

class _CreateAnnouncementDialog extends ConsumerStatefulWidget {
  const _CreateAnnouncementDialog({required this.familyId});

  final String familyId;

  @override
  ConsumerState<_CreateAnnouncementDialog> createState() =>
      _CreateAnnouncementDialogState();
}

class _CreateAnnouncementDialogState
    extends ConsumerState<_CreateAnnouncementDialog> {
  final _bodyController = TextEditingController();

  @override
  void dispose() {
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    if (_bodyController.text.trim().isEmpty) return;

    await ref.read(announcementRepositoryProvider).createAnnouncement(
          familyId: widget.familyId,
          body: _bodyController.text,
        );

    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New announcement'),
      content: TextField(
        controller: _bodyController,
        decoration: const InputDecoration(
          labelText: 'What\'s happening?',
          hintText: 'Soccer practice moved to 4pm...',
        ),
        maxLines: 4,
        autofocus: true,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _post,
          child: const Text('Post'),
        ),
      ],
    );
  }
}

class _AnnouncementCard extends ConsumerStatefulWidget {
  const _AnnouncementCard({
    required this.announcement,
    required this.familyId,
  });

  final Announcement announcement;
  final String familyId;

  @override
  ConsumerState<_AnnouncementCard> createState() => _AnnouncementCardState();
}

class _AnnouncementCardState extends ConsumerState<_AnnouncementCard> {
  bool _showComments = false;
  final _commentController = TextEditingController();

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final announcement = widget.announcement;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (announcement.isPinned)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.push_pin,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                Expanded(
                  child: Text(
                    announcement.author?.displayName ?? 'Family member',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
                Text(
                  DateFormat('MMM d, h:mm a').format(announcement.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                IconButton(
                  icon: Icon(
                    announcement.isPinned
                        ? Icons.push_pin
                        : Icons.push_pin_outlined,
                  ),
                  tooltip: announcement.isPinned ? 'Unpin' : 'Pin',
                  onPressed: () async {
                    await ref
                        .read(announcementRepositoryProvider)
                        .togglePin(
                          announcementId: announcement.id,
                          isPinned: !announcement.isPinned,
                        );
                    ref.invalidate(announcementsProvider(widget.familyId));
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(announcement.body),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => setState(() => _showComments = !_showComments),
                  icon: const Icon(Icons.comment_outlined, size: 18),
                  label: Text('${announcement.comments.length} comments'),
                ),
              ],
            ),
            if (_showComments) ...[
              const Divider(),
              ...announcement.comments.map(
                (c) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 14,
                        child: Text(
                          (c.author?.displayName ?? '?')[0].toUpperCase(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.author?.displayName ?? 'Member',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Text(c.body),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Add a comment...',
                        isDense: true,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () async {
                      if (_commentController.text.trim().isEmpty) return;
                      await ref
                          .read(announcementRepositoryProvider)
                          .addComment(
                            announcementId: announcement.id,
                            body: _commentController.text,
                          );
                      _commentController.clear();
                      ref.invalidate(announcementsProvider(widget.familyId));
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
