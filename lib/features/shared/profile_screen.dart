import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waste_bridge/core/theme/app_tokens.dart';
import 'package:waste_bridge/core/ui/user_safe_error.dart';
import 'package:waste_bridge/features/shared/app_widgets.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool? _collectorAvailable;
  bool _saving = false;
  bool _seeded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final u = ref.read(authNotifierProvider).valueOrNull;
      if (!mounted || u == null || _seeded) return;
      setState(() {
        _name.text = u.name;
        _collectorAvailable = u.collectorAvailable;
        _seeded = true;
      });
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: auth.when(
        data: (u) {
          if (u == null) {
            return const CenterState(
              title: 'Not signed in',
              subtitle: 'Log in to manage your profile.',
              icon: Icons.person_off_outlined,
            );
          }
          final isCollector = u.role == UserRole.collector;
          return ListView(
            padding: EdgeInsets.all(AppSpacing.md),
            children: [
              AppSectionCard(
                title: 'Account',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: 'Display name',
                      ),
                      textCapitalization: TextCapitalization.words,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone (M-Pesa)',
                        hintText: 'E.g. +254712345678',
                      ),
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      u.email,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    SizedBox(height: AppSpacing.xs),
                    Text(
                      'Role: ${u.role.toString().split('.').last}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    SizedBox(height: AppSpacing.sm),
                    Text(
                      'KYC: ${u.kycStatus.name}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (isCollector) ...[
                SizedBox(height: AppSpacing.sm),
                AppSectionCard(
                  title: 'Collector',
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Available for new jobs'),
                    subtitle: const Text(
                      'When on, you can see open pickups in the marketplace feed.',
                    ),
                    value: _collectorAvailable ?? u.collectorAvailable ?? false,
                    onChanged: (v) => setState(() => _collectorAvailable = v),
                  ),
                ),
              ],
              SizedBox(height: AppSpacing.sm),
              AppSectionCard(
                title: 'Verification',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.verified_user_outlined),
                      title: const Text('KYC submissions'),
                      subtitle: const Text('Upload ID documents for verification'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/kyc'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.star_outline),
                      title: const Text('Your public ratings'),
                      subtitle: const Text('Reviews from other users'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/users/${u.id}/ratings'),
                    ),
                  ],
                ),
              ),
              SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _saving
                    ? null
                    : () async {
                        setState(() => _saving = true);
                        try {
                          await ref.read(authNotifierProvider.notifier).updateProfile(
                                name: _name.text.trim().isEmpty
                                    ? null
                                    : _name.text.trim(),
                                includePhone: true,
                                phone: _phone.text,
                                collectorAvailable: isCollector
                                    ? (_collectorAvailable ??
                                        u.collectorAvailable ??
                                        false)
                                    : null,
                              );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Profile saved.')),
                          );
                        } catch (e) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                userVisibleError(e, fallback: 'Could not save profile.'),
                              ),
                            ),
                          );
                        } finally {
                          if (mounted) setState(() => _saving = false);
                        }
                      },
                child: _saving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save changes'),
              ),
              SizedBox(height: AppSpacing.md),
              OutlinedButton.icon(
                onPressed: () async {
                  await ref.read(authNotifierProvider.notifier).logout();
                  if (!context.mounted) return;
                  context.go('/role');
                },
                icon: const Icon(Icons.logout),
                label: const Text('Log out'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => CenterState(
          title: 'Error',
          subtitle: '$e',
          icon: Icons.error_outline,
        ),
      ),
    );
  }
}
