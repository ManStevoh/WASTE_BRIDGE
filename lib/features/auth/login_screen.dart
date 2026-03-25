import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waste_bridge/features/auth/widgets/auth_role_dropdown.dart';
import 'package:waste_bridge/features/auth/widgets/auth_submit_button.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController(text: 'amina@generator.com');
  final _password = TextEditingController(text: '123456');

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedRole = ref.watch(selectedRoleProvider);
    final authState = ref.watch(authNotifierProvider);

    ref.listen<AsyncValue>(authNotifierProvider, (_, next) {
      next.whenOrNull(data: (user) {
        if (user != null && mounted) {
          context.go('/${user.role.toString().split('.').last}');
        }
      });
    });

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 32),
            Text('Waste Bridge', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text('Login to connect waste to value.'),
            const SizedBox(height: 24),
            AuthRoleDropdown(
              selectedRole: selectedRole,
              onChanged: (role) => ref.read(selectedRoleProvider.notifier).state = role,
            ),
            const SizedBox(height: 16),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
            const SizedBox(height: 12),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 20),
            AuthSubmitButton(
              label: 'Login',
              isLoading: authState.isLoading,
              onPressed: () {
                ref
                    .read(authNotifierProvider.notifier)
                    .login(_email.text.trim(), _password.text.trim(), selectedRole);
              },
            ),
            TextButton(
              onPressed: () => context.push('/register'),
              child: const Text('Create new account'),
            ),
          ],
        ),
      ),
    );
  }
}
