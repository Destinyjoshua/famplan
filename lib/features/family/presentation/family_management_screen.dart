import 'package:famplan/core/theme/app_theme.dart';
import 'package:famplan/core/utils/email_utils.dart';
import 'package:famplan/core/utils/responsive.dart';
import 'package:famplan/data/models/family.dart';
import 'package:famplan/data/models/profile.dart';
import 'package:famplan/providers/auth_provider.dart';
import 'package:famplan/providers/family_provider.dart';
import 'package:famplan/shared/widgets/loading_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class FamilyManagementScreen extends ConsumerWidget {
  const FamilyManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final familyAsync = ref.watch(currentFamilyProvider);
    final profileAsync = ref.watch(profileProvider);
    final membershipAsync = ref.watch(currentFamilyMembershipProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family'),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: pageMaxWidth(context)),
          child: familyAsync.when(
        loading: () => const LoadingView(message: 'Loading family...'),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (family) {
          if (family == null) {
            return const Center(child: Text('No family found'));
          }

          final membersAsync = ref.watch(familyMembersProvider(family.id));
          final currentUserId = ref.watch(currentUserProvider)?.id;
          final isAdmin = membershipAsync.value?.isAdmin ?? false;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(currentFamilyProvider);
              ref.invalidate(familyMembersProvider(family.id));
              ref.invalidate(currentFamilyMembershipProvider);
              ref.invalidate(profileProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _FamilyHeaderCard(
                  family: family,
                  memberCount: membersAsync.value?.length,
                  isAdmin: isAdmin,
                  onRename: () => _showRenameDialog(context, ref, family),
                ),
                const SizedBox(height: 16),
                _InviteCard(
                  family: family,
                  isAdmin: isAdmin,
                  onCopy: () => _copyInviteCode(context, family),
                  onRegenerate: isAdmin
                      ? () => _regenerateInviteCode(context, ref, family)
                      : null,
                ),
                const SizedBox(height: 16),
                _QuickLinksCard(
                  planName: family.subscription.plan.name,
                  onHealth: () => context.push('/health'),
                  onPlans: () => context.push('/plans'),
                ),
                const SizedBox(height: 16),
                _SectionTitle(
                  title: 'Members',
                  subtitle: '${membersAsync.value?.length ?? 0} in your family',
                ),
                const SizedBox(height: 8),
                membersAsync.when(
                  loading: () => const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                  error: (e, _) => Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Could not load members: $e'),
                    ),
                  ),
                  data: (members) => Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < members.length; i++) ...[
                          _MemberTile(
                            member: members[i],
                            isSelf: members[i].userId == currentUserId,
                            isAdminViewer: isAdmin,
                            onAction: (action) => _handleMemberAction(
                              context,
                              ref,
                              family: family,
                              member: members[i],
                              action: action,
                            ),
                          ),
                          if (i < members.length - 1) const Divider(height: 1),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionTitle(title: 'Your profile'),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.teal.withValues(alpha: 0.15),
                      child: Text(
                        _initials(profileAsync.value?.displayName ?? '?'),
                        style: const TextStyle(
                          color: AppTheme.teal,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    title: Text(
                      profileAsync.value?.displayName ?? 'Family Member',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      _profileSubtitle(profileAsync.value),
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () => _showEditProfileDialog(
                      context,
                      ref,
                      displayName: profileAsync.value?.displayName ?? '',
                      contactEmail: profileAsync.value?.contactEmail,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _SectionTitle(title: 'Account'),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.logout, color: AppTheme.coral),
                        title: const Text('Sign out'),
                        onTap: () =>
                            ref.read(authControllerProvider.notifier).signOut(),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(
                          Icons.exit_to_app,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: Text(
                          'Leave family',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        subtitle: const Text(
                          'You can rejoin later with an invite code',
                        ),
                        onTap: () => _confirmLeaveFamily(context, ref, family),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
          ),
        ),
      ),
    );
  }

  String _profileSubtitle(Profile? profile) {
    if (profile == null) return 'No profile on file';

    final parts = <String>[];
    if (profile.phone != null && profile.phone!.isNotEmpty) {
      parts.add(profile.phone!);
    }
    if (profile.contactEmail != null && profile.contactEmail!.isNotEmpty) {
      parts.add(profile.contactEmail!);
    } else {
      parts.add('Add email for family updates');
    }

    return parts.join(' · ');
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  void _copyInviteCode(BuildContext context, Family family) {
    final code = family.inviteCode;
    if (code == null || code.isEmpty) return;

    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Invite code copied')),
    );
  }

  Future<void> _regenerateInviteCode(
    BuildContext context,
    WidgetRef ref,
    Family family,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New invite code?'),
        content: const Text(
          'This will invalidate the current code. Anyone with the old code will no longer be able to join.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(familyControllerProvider.notifier)
          .regenerateInviteCode(family.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New invite code generated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, e);
      }
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    WidgetRef ref,
    Family family,
  ) async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _RenameFamilyDialog(initialName: family.name),
    );

    if (name == null || name.isEmpty || !context.mounted) return;

    try {
      await ref.read(familyControllerProvider.notifier).updateFamilyName(
            familyId: family.id,
            name: name,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Family name updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, e);
      }
    }
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    WidgetRef ref, {
    required String displayName,
    String? contactEmail,
  }) async {
    final result = await showDialog<ProfileEditResult>(
      context: context,
      builder: (context) => _EditProfileDialog(
        initialName: isPlaceholderDisplayName(displayName)
            ? ''
            : displayName,
        initialEmail: contactEmail ?? '',
      ),
    );

    if (result == null || !context.mounted) return;

    final error = await ref.read(authControllerProvider.notifier).updateProfile(
          result.displayName,
          contactEmail: result.contactEmail,
        );
    if (!context.mounted) return;

    if (error != null) {
      _showError(context, error);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    }
  }

  Future<void> _handleMemberAction(
    BuildContext context,
    WidgetRef ref, {
    required Family family,
    required FamilyMember member,
    required _MemberAction action,
  }) async {
    try {
      final controller = ref.read(familyControllerProvider.notifier);
      switch (action) {
        case _MemberAction.makeAdmin:
          await controller.updateMemberRole(
            familyId: family.id,
            userId: member.userId,
            role: 'admin',
          );
          break;
        case _MemberAction.makeMember:
          await controller.updateMemberRole(
            familyId: family.id,
            userId: member.userId,
            role: 'member',
          );
          break;
        case _MemberAction.remove:
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Remove member?'),
              content: Text(
                'Remove ${member.profile?.displayName ?? 'this member'} from ${family.name}?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                  child: const Text('Remove'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
          await controller.removeMember(
            familyId: family.id,
            userId: member.userId,
          );
          break;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member updated')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, e);
      }
    }
  }

  Future<void> _confirmLeaveFamily(
    BuildContext context,
    WidgetRef ref,
    Family family,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave family?'),
        content: Text(
          'You will lose access to ${family.name}. You can rejoin with an invite code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(familyControllerProvider.notifier).leaveFamily(family.id);
      if (context.mounted) {
        context.go('/onboarding');
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, e);
      }
    }
  }

  void _showError(BuildContext context, Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _RenameFamilyDialog extends StatefulWidget {
  const _RenameFamilyDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameFamilyDialog> createState() => _RenameFamilyDialogState();
}

class _RenameFamilyDialogState extends State<_RenameFamilyDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rename family'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(labelText: 'Family name'),
        onSubmitted: (_) => _save(),
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

class ProfileEditResult {
  const ProfileEditResult({
    required this.displayName,
    this.contactEmail,
  });

  final String displayName;
  final String? contactEmail;
}

class _EditProfileDialog extends StatefulWidget {
  const _EditProfileDialog({
    required this.initialName,
    required this.initialEmail,
  });

  final String initialName;
  final String initialEmail;

  @override
  State<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<_EditProfileDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _save() {
    final name = _nameController.text.trim();
    final emailInput = _emailController.text.trim();

    if (name.isEmpty) return;

    if (emailInput.isNotEmpty && normalizeContactEmail(emailInput) == null) {
      setState(() => _emailError = 'Enter a valid email address');
      return;
    }

    Navigator.pop(
      context,
      ProfileEditResult(
        displayName: name,
        contactEmail: emailInput.isEmpty ? '' : emailInput,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: 'Email (optional)',
                hintText: 'you@example.com',
                errorText: _emailError,
                helperText: 'Sign-in stays on your phone number.',
              ),
              onChanged: (_) {
                if (_emailError != null) {
                  setState(() => _emailError = null);
                }
              },
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
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}

enum _MemberAction { makeAdmin, makeMember, remove }

class _FamilyHeaderCard extends StatelessWidget {
  const _FamilyHeaderCard({
    required this.family,
    required this.memberCount,
    required this.isAdmin,
    required this.onRename,
  });

  final Family family;
  final int? memberCount;
  final bool isAdmin;
  final VoidCallback onRename;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.teal, Color(0xFF5EDDD0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.teal.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.family_restroom, color: Colors.white, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  family.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  memberCount != null
                      ? '$memberCount member${memberCount == 1 ? '' : 's'}'
                      : 'Your family hub',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
          if (isAdmin)
            IconButton(
              onPressed: onRename,
              icon: const Icon(Icons.edit_outlined, color: Colors.white),
              tooltip: 'Rename family',
            ),
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.family,
    required this.isAdmin,
    required this.onCopy,
    this.onRegenerate,
  });

  final Family family;
  final bool isAdmin;
  final VoidCallback onCopy;
  final VoidCallback? onRegenerate;

  String? _expiryLabel() {
    final expires = family.inviteCodeExpiresAt;
    if (expires == null) return null;
    return 'Expires ${DateFormat.MMMd().add_jm().format(expires.toLocal())}';
  }

  @override
  Widget build(BuildContext context) {
    final code = family.inviteCode ?? '—';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.violet.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.link, color: AppTheme.violet),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Invite code',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        'Share so others can join',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    code,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          letterSpacing: 3,
                          fontWeight: FontWeight.bold,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  if (_expiryLabel() != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      _expiryLabel()!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: family.inviteCode == null ? null : onCopy,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy'),
                  ),
                ),
                if (onRegenerate != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onRegenerate,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('New code'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLinksCard extends StatelessWidget {
  const _QuickLinksCard({
    required this.planName,
    required this.onHealth,
    required this.onPlans,
  });

  final String planName;
  final VoidCallback onHealth;
  final VoidCallback onPlans;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.coral.withValues(alpha: 0.12),
              child: const Icon(Icons.favorite_outline, color: AppTheme.coral),
            ),
            title: const Text('Family health'),
            subtitle: const Text('Activity score and coaching tips'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onHealth,
          ),
          const Divider(height: 1),
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppTheme.teal.withValues(alpha: 0.12),
              child: const Icon(Icons.workspace_premium_outlined, color: AppTheme.teal),
            ),
            title: const Text('Plans'),
            subtitle: Text('Current plan: $planName'),
            trailing: const Icon(Icons.chevron_right),
            onTap: onPlans,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
        ],
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.isSelf,
    required this.isAdminViewer,
    required this.onAction,
  });

  final FamilyMember member;
  final bool isSelf;
  final bool isAdminViewer;
  final void Function(_MemberAction action) onAction;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final name = member.profile?.displayName ?? 'Family Member';
    final canManage = isAdminViewer && !isSelf;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: member.isAdmin
            ? AppTheme.coral.withValues(alpha: 0.15)
            : AppTheme.teal.withValues(alpha: 0.12),
        child: Text(
          _initials(name),
          style: TextStyle(
            color: member.isAdmin ? AppTheme.coral : AppTheme.teal,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isSelf) ...[
            const SizedBox(width: 6),
            Text(
              '(you)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      subtitle: Text(
        [
          member.roleLabel,
          if (member.profile?.phone != null) member.profile!.phone!,
        ].join(' · '),
      ),
      trailing: canManage
          ? PopupMenuButton<_MemberAction>(
              onSelected: onAction,
              itemBuilder: (context) => [
                if (!member.isAdmin)
                  const PopupMenuItem(
                    value: _MemberAction.makeAdmin,
                    child: Text('Make admin'),
                  ),
                if (member.isAdmin)
                  const PopupMenuItem(
                    value: _MemberAction.makeMember,
                    child: Text('Make member'),
                  ),
                const PopupMenuItem(
                  value: _MemberAction.remove,
                  child: Text('Remove from family'),
                ),
              ],
            )
          : member.isAdmin
              ? const Chip(
                  label: Text('Admin'),
                  backgroundColor: Color(0xFFFFE8E8),
                  visualDensity: VisualDensity.compact,
                )
              : null,
    );
  }
}