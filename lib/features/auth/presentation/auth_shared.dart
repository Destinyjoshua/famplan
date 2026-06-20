import 'package:famplan/core/theme/app_theme.dart';
import 'package:famplan/core/utils/phone_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String friendlyAuthError(Object error) {
  final message = error.toString().toLowerCase();
  if (message.contains('invalid or expired verification code') ||
      message.contains('invalid login credentials')) {
    return 'Invalid or expired code. Request a new one and try again.';
  }
  if (message.contains('could not send verification code') ||
      message.contains('sms service is not configured')) {
    return 'Could not send SMS code. Try again in a moment.';
  }
  if (message.contains('user already registered') ||
      message.contains('already been registered')) {
    return 'This number already has an account. Sign in with a new code.';
  }
  if (message.contains('phone_provider_disabled')) {
    return 'Phone sign-in is not enabled on the server. Contact support.';
  }
  if (message.contains('valid nigerian')) {
    return 'Enter a valid Nigerian number, e.g. ${formatPhoneHint()} or +2348012345678';
  }
  if (message.contains('function') && message.contains('not found')) {
    return 'SMS login is not deployed yet. Contact support.';
  }
  return error.toString().replaceFirst('AuthException: ', '').replaceFirst(
        'Exception: ',
        '',
      );
}

class AuthBranding extends StatelessWidget {
  const AuthBranding({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppTheme.coral, AppTheme.teal],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.coral.withValues(alpha: 0.25),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: const Icon(
            Icons.family_restroom,
            size: 44,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'FamPlan',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.65),
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class PhoneField extends StatelessWidget {
  const PhoneField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      autocorrect: false,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]')),
      ],
      decoration: InputDecoration(
        labelText: 'Phone number',
        hintText: formatPhoneHint(),
        prefixIcon: const Icon(Icons.phone_outlined),
        helperText: formatPhoneHelper(),
      ),
      validator: (value) {
        if (normalizePhone(value ?? '') == null) {
          return 'Enter 080... or +234... (11 digits)';
        }
        return null;
      },
    );
  }
}

class OtpField extends StatelessWidget {
  const OtpField({super.key, required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            letterSpacing: 8,
            fontWeight: FontWeight.w700,
          ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      decoration: const InputDecoration(
        labelText: 'Verification code',
        hintText: '123456',
        prefixIcon: Icon(Icons.sms_outlined),
      ),
      validator: (value) {
        if (value == null || !RegExp(r'^\d{6}$').hasMatch(value)) {
          return 'Enter the 6-digit code from SMS';
        }
        return null;
      },
    );
  }
}

class AuthScreenLayout extends StatelessWidget {
  const AuthScreenLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.coral.withValues(alpha: 0.08),
              AppTheme.warmCream,
              AppTheme.warmCream,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(
                      color: AppTheme.warmBrown.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}