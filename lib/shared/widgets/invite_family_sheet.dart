import 'package:famplan/data/models/family.dart';
import 'package:famplan/providers/family_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

class InviteFamilySheet extends ConsumerWidget {
  const InviteFamilySheet({super.key, required this.family});

  final Family family;

  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final family = await ref.read(currentFamilyProvider.future);
    if (family == null || !context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => InviteFamilySheet(family: family),
    );
  }

  void _copyCode(BuildContext context) {
    final code = family.inviteCode;
    if (code == null || code.isEmpty) return;

    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied')),
    );
  }

  String? _expiryLabel() {
    final expires = family.inviteCodeExpiresAt;
    if (expires == null) return null;
    return 'Expires ${DateFormat.MMMd().add_jm().format(expires.toLocal())}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(familyMembersProvider(family.id));
    final code = family.inviteCode ?? '—';

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Invite family members',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Share this code so others can join ${family.name}.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    code,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          letterSpacing: 4,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (_expiryLabel() != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _expiryLabel()!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: family.inviteCode == null
                  ? null
                  : () => _copyCode(context),
              icon: const Icon(Icons.copy),
              label: const Text('Copy invite code'),
            ),
            const SizedBox(height: 24),
            Text(
              'How it works',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            const _Step(number: '1', text: 'Copy the code above'),
            const _Step(
              number: '2',
              text: 'Send it via WhatsApp, iMessage, or email',
            ),
            const _Step(
              number: '3',
              text: 'They open FamPlan → Join with code → enter the code',
            ),
            const SizedBox(height: 20),
            membersAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
              data: (members) => Text(
                '${members.length} family member${members.length == 1 ? '' : 's'} joined',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 12,
            child: Text(number, style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}