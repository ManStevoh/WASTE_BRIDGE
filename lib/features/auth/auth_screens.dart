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
          for (final role in UserRole.values)
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
            _RoleDropdown(
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
            _AuthSubmitButton(
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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
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
      appBar: AppBar(title: const Text('Register')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
          const SizedBox(height: 12),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 12),
          _RoleDropdown(
            selectedRole: selectedRole,
            onChanged: (role) => ref.read(selectedRoleProvider.notifier).state = role,
          ),
          const SizedBox(height: 20),
          _AuthSubmitButton(
            label: 'Register',
            isLoading: authState.isLoading,
            onPressed: () {
              ref.read(authNotifierProvider.notifier).register(
                    _name.text.trim(),
                    _email.text.trim(),
                    _password.text.trim(),
                    selectedRole,
                  );
            },
          ),
        ],
      ),
    );
  }
}

class _RoleDropdown extends StatelessWidget {
  const _RoleDropdown({
    required this.selectedRole,
    required this.onChanged,
  });

  final UserRole selectedRole;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<UserRole>(
      value: selectedRole,
      decoration: const InputDecoration(labelText: 'Role'),
      items: UserRole.values
          .map(
            (role) => DropdownMenuItem(
              value: role,
              child: Text(role.toString().split('.').last.toUpperCase()),
            ),
          )
          .toList(),
      onChanged: (role) {
        if (role != null) onChanged(role);
      },
    );
  }
}

class _AuthSubmitButton extends StatelessWidget {
  const _AuthSubmitButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isLoading ? null : onPressed,
      child: isLoading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(label),
    );
  }
}

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  static const _pages = [
    (
      icon: Icons.recycling_rounded,
      title: 'Welcome to Waste Bridge',
      description: 'Connect waste generators, collectors, and recyclers in one marketplace.'
    ),
    (
      icon: Icons.route_rounded,
      title: 'Track Waste Requests',
      description: 'Create pickup requests and follow progress from assignment to completion.'
    ),
    (
      icon: Icons.payments_rounded,
      title: 'Create Shared Value',
      description: 'Turn waste into revenue while supporting efficient, transparent operations.'
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goToRoleSelection() {
    context.go('/role');
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _index == _pages.length - 1;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _goToRoleSelection,
                  child: const Text('Skip'),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: (value) => setState(() => _index = value),
                  itemBuilder: (context, index) {
                    final page = _pages[index];
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircleAvatar(
                          radius: 44,
                          child: Icon(page.icon, size: 44),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          page.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          page.description,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (dotIndex) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _index == dotIndex ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _index == dotIndex
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (isLast) {
                      _goToRoleSelection();
                      return;
                    }
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOut,
                    );
                  },
                  child: Text(isLast ? 'Get Started' : 'Next'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
