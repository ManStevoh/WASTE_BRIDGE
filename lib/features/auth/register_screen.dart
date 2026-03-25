import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:waste_bridge/core/constants/app_constants.dart';
import 'package:waste_bridge/core/ui/user_safe_error.dart';
import 'package:waste_bridge/features/auth/widgets/auth_role_dropdown.dart';
import 'package:waste_bridge/features/auth/widgets/auth_submit_button.dart';
import 'package:waste_bridge/providers/app_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();
  final _otpCode = TextEditingController();

  bool _otpBusy = false;
  bool _otpSent = false;
  bool _phoneVerified = false;
  String? _verificationToken;
  String? _verifiedPhoneE164;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _otpCode.dispose();
    super.dispose();
  }

  void _onPhoneChanged() {
    final t = _phone.text.trim();
    if (t.isEmpty) {
      setState(() {
        _otpSent = false;
        _phoneVerified = false;
        _verificationToken = null;
        _verifiedPhoneE164 = null;
      });
      return;
    }
    if (_phoneVerified &&
        _verifiedPhoneE164 != null &&
        t != _verifiedPhoneE164) {
      setState(() {
        _phoneVerified = false;
        _verificationToken = null;
        _verifiedPhoneE164 = null;
        _otpSent = false;
      });
    }
  }

  bool _isValidEmail(String value) {
    final v = value.trim();
    return RegExp(r'^.+@.+\..+').hasMatch(v);
  }

  Future<void> _sendOtp() async {
    final phone = _phone.text.trim();
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid phone number (E.164 or local, min ~10 digits).'),
        ),
      );
      return;
    }
    setState(() => _otpBusy = true);
    try {
      await ref.read(authServiceProvider).requestOtp(phone: phone);
      if (!mounted) return;
      setState(() => _otpSent = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('If SMS is enabled, a code was sent to your phone.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userVisibleError(e, fallback: 'Could not send code.'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _otpBusy = false);
    }
  }

  Future<void> _verifyOtp() async {
    final phone = _phone.text.trim();
    final code = _otpCode.text.trim();
    if (code.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 6-digit code.')),
      );
      return;
    }
    setState(() => _otpBusy = true);
    try {
      final result = await ref.read(authServiceProvider).verifyOtp(
            phone: phone,
            code: code,
          );
      if (!mounted) return;
      setState(() {
        _verificationToken = result.verificationToken;
        _verifiedPhoneE164 = result.phone;
        _phoneVerified = true;
        _phone.text = result.phone;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone verified. You can register.')),
      );
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(userVisibleError(e, fallback: 'Invalid or expired code.'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    } finally {
      if (mounted) setState(() => _otpBusy = false);
    }
  }

  void _submit() {
    final name = _name.text.trim();
    final email = _email.text.trim();
    final password = _password.text.trim();
    final phoneRaw = _phone.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your full name.')),
      );
      return;
    }
    if (!_isValidEmail(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }
    if (password.length < AppConstants.minRegisterPasswordLength) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Password must be at least ${AppConstants.minRegisterPasswordLength} characters.',
          ),
        ),
      );
      return;
    }
    if (phoneRaw.isNotEmpty && !_phoneVerified) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verify your phone number or clear the phone field.'),
        ),
      );
      return;
    }

    ref.read(authNotifierProvider.notifier).register(
          name,
          email,
          password,
          ref.read(selectedRoleProvider),
          phone: _phoneVerified ? _verifiedPhoneE164 : null,
          phoneVerificationToken: _phoneVerified ? _verificationToken : null,
        );
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
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Full name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Password',
              helperText:
                  'At least ${AppConstants.minRegisterPasswordLength} characters (server rule).',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            autocorrect: false,
            onChanged: (_) => _onPhoneChanged(),
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              helperText: 'E.164 or local number. Send code, then verify before registering.',
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _otpBusy ||
                          _phoneVerified ||
                          _phone.text.trim().length < 10
                      ? null
                      : _sendOtp,
                  child: _otpBusy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send code'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: _otpBusy || !_otpSent || _phoneVerified ? null : _verifyOtp,
                  child: const Text('Verify'),
                ),
              ),
            ],
          ),
          if (_phoneVerified) ...[
            const SizedBox(height: 8),
            Text(
              'Phone verified',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
          const SizedBox(height: 8),
          TextField(
            controller: _otpCode,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'SMS code (6 digits)',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          AuthRoleDropdown(
            selectedRole: selectedRole,
            onChanged: (role) => ref.read(selectedRoleProvider.notifier).state = role,
          ),
          const SizedBox(height: 20),
          AuthSubmitButton(
            label: 'Register',
            isLoading: authState.isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
