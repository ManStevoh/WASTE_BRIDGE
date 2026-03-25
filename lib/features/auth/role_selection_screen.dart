import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waste_bridge/models/app_enums.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class RoleSelectionScreen extends ConsumerWidget {
  const RoleSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose Role')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text('Continue as one of the marketplace users.'),
          const SizedBox(height: 20),
          for (final role in UserRole.values.where((r) => r != UserRole.admin))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: FilledButton.tonal(
                onPressed: () {
                  ref.read(selectedRoleProvider.notifier).state = role;
                  context.push('/login');
                },
                child: Text(role.toString().split('.').last.toUpperCase()),
              ),
            ),
        ],
      ),
    );
  }
}
