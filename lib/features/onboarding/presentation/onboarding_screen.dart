import 'package:famplan/core/theme/app_theme.dart';
import 'package:famplan/providers/auth_provider.dart';
import 'package:famplan/providers/family_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _familyNameController = TextEditingController();
  final _inviteCodeController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _showJoin = false;

  @override
  void dispose() {
    _familyNameController.dispose();
    _inviteCodeController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _createFamily() async {
    final name = _familyNameController.text.trim();
    if (name.isEmpty) {
      _showError('Enter a family name');
      return;
    }

    await _ensureProfile();

    try {
      await ref.read(familyControllerProvider.notifier).createFamily(name);
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _joinFamily() async {
    final code = _inviteCodeController.text.trim();
    if (code.isEmpty) {
      _showError('Enter an invite code');
      return;
    }

    await _ensureProfile();

    try {
      await ref.read(familyControllerProvider.notifier).joinFamily(code);
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _ensureProfile() async {
    final displayName = _displayNameController.text.trim();
    if (displayName.isEmpty) return;

    final error = await ref
        .read(authControllerProvider.notifier)
        .updateProfile(displayName);
    if (error != null) {
      throw Exception(error);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading =
        ref.watch(familyControllerProvider).isLoading ||
            ref.watch(authControllerProvider).isLoading;

    ref.listen(familyControllerProvider, (previous, next) {
      final error = next.error;
      if (error != null) {
        _showError(error.toString());
      }
    });

    ref.listen(profileProvider, (previous, next) {
      final displayName = next.value?.displayName;
      if (displayName != null &&
          displayName.isNotEmpty &&
          _displayNameController.text.isEmpty) {
        _displayNameController.text = displayName;
      }
    });

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.teal.withValues(alpha: 0.1),
              AppTheme.warmCream,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                Text(
                  'Set up your family',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tell us who you are, then create a new family or join with an invite code.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.65),
                      ),
                ),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _displayNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Your display name',
                            prefixIcon: Icon(Icons.person_outline),
                            hintText: 'e.g. Joshua',
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'How do you want to get started?',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ChoiceCard(
                                selected: !_showJoin,
                                icon: Icons.home_outlined,
                                title: 'Create',
                                subtitle: 'Start a new family',
                                color: AppTheme.coral,
                                onTap: () => setState(() => _showJoin = false),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _ChoiceCard(
                                selected: _showJoin,
                                icon: Icons.vpn_key_outlined,
                                title: 'Join',
                                subtitle: 'Use invite code',
                                color: AppTheme.teal,
                                onTap: () => setState(() => _showJoin = true),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        if (_showJoin) ...[
                          TextField(
                            controller: _inviteCodeController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Invite code',
                              prefixIcon: Icon(Icons.vpn_key_outlined),
                              hintText: 'ABC12345',
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: isLoading ? null : _joinFamily,
                            icon: isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.group_add),
                            label: const Text('Join family'),
                          ),
                        ] else ...[
                          TextField(
                            controller: _familyNameController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Family name',
                              prefixIcon: Icon(Icons.home_outlined),
                              hintText: 'The Eze Family',
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: isLoading ? null : _createFamily,
                            icon: isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.add_home),
                            label: const Text('Create family'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.1) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? color : color.withValues(alpha: 0.2),
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.55),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}