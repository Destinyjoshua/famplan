import 'package:famplan/features/auth/presentation/phone_otp_auth_screen.dart';
import 'package:flutter/material.dart';

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PhoneOtpAuthScreen(isSignUp: true);
  }
}