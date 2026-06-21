import 'package:famplan/core/utils/responsive.dart';
import 'package:famplan/features/auth/presentation/auth_shared.dart';
import 'package:famplan/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

class PhoneOtpAuthScreen extends ConsumerStatefulWidget {
  const PhoneOtpAuthScreen({super.key, this.isSignUp = false});

  final bool isSignUp;

  @override
  ConsumerState<PhoneOtpAuthScreen> createState() => _PhoneOtpAuthScreenState();
}

class _PhoneOtpAuthScreenState extends ConsumerState<PhoneOtpAuthScreen> {
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneFormKey = GlobalKey<FormState>();
  final _otpFormKey = GlobalKey<FormState>();

  bool _codeSent = false;
  String? _pinId;
  String? _normalizedPhone;

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_phoneFormKey.currentState!.validate()) return;

    try {
      final result = await ref
          .read(authControllerProvider.notifier)
          .sendOtp(phone: _phoneController.text);

      if (!mounted) return;

      setState(() {
        _codeSent = true;
        _pinId = result.pinId;
        _normalizedPhone = result.phone;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification code sent by SMS')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyAuthError(error))),
      );
    }
  }

  Future<void> _verifyCode() async {
    if (!_otpFormKey.currentState!.validate()) return;
    if (_pinId == null || _normalizedPhone == null) return;

    try {
      await ref.read(authControllerProvider.notifier).verifyOtp(
            phone: _normalizedPhone!,
            pinId: _pinId!,
            pin: _otpController.text,
          );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyAuthError(error))),
      );
    }
  }

  void _changePhone() {
    setState(() {
      _codeSent = false;
      _pinId = null;
      _normalizedPhone = null;
      _otpController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authControllerProvider).isLoading;

    return AuthScreenLayout(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthBranding(
            title: widget.isSignUp ? 'Create your account' : 'Welcome back',
            subtitle: _codeSent
                ? 'Enter the 6-digit code sent to your phone'
                : isWebPlatform()
                    ? 'Sign in with your Nigerian phone number. The SMS code arrives on your phone.'
                    : 'We will text you a one-time verification code',
          ),
          if (isWebPlatform() && _codeSent) ...[
            const SizedBox(height: 12),
            Text(
              'Check the text message on your phone, then enter the code here.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.65),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 32),
          if (!_codeSent) ...[
            Form(
              key: _phoneFormKey,
              child: PhoneField(controller: _phoneController),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: isLoading ? null : _sendCode,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send code'),
            ),
          ] else ...[
            if (_normalizedPhone != null)
              Text(
                'Code sent to ${_normalizedPhone!}',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            const SizedBox(height: 16),
            Form(
              key: _otpFormKey,
              child: OtpField(controller: _otpController),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: isLoading ? null : _verifyCode,
              child: isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(widget.isSignUp ? 'Verify & create account' : 'Verify & sign in'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: isLoading ? null : _sendCode,
              child: const Text('Resend code'),
            ),
            TextButton(
              onPressed: isLoading ? null : _changePhone,
              child: const Text('Change phone number'),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.isSignUp
                    ? 'Already have an account?'
                    : 'New to FamPlan?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              TextButton(
                onPressed: isLoading
                    ? null
                    : () => context.go(widget.isSignUp ? '/login' : '/signup'),
                child: Text(widget.isSignUp ? 'Sign in' : 'Create account'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}