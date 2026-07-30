import 'package:flutter/material.dart';
import 'package:schedly/services/authentication_service.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_button.dart';
import 'widgets/schedly_card.dart';
import 'widgets/schedly_text_field.dart';
import 'widgets/app_dialogs.dart';
import 'widgets/animations/animated_auth_background.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailController = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      AppDialogs.showError(
        context: context,
        title: 'Invalid Email',
        message: 'Please enter a valid email address.',
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await AuthenticationService.sendPasswordResetEmail(email);
      setState(() => _sent = true);
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showError(
        context: context,
        title: 'Error',
        message: e.toString().replaceAll(RegExp(r'\[.*\]\s*'), ''),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedAuthBackground(
      isCenteredLogo: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(AppSpacing.x2l),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: _sent ? _buildSuccessState() : _buildInputState(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputState() {
    return SchedlyCard(
      variant: SchedlyCardVariant.elevated,
      padding: EdgeInsets.all(AppSpacing.x3l),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.lock_reset_rounded,
              size: 40,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),
          Text(
            'Forgot your password?',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Enter your email address and we will send you a link to reset your password.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: AppSpacing.x3l),
          SchedlyTextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            labelText: 'Email Address',
            prefixIcon: Icons.email_rounded,
          ),
          const SizedBox(height: AppSpacing.x2l),
          AnimatedButton(
            onPressed: _loading ? null : _resetPassword,
            isLoading: _loading,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            child: const Text('Send Reset Link', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return SchedlyCard(
      variant: SchedlyCardVariant.elevated,
      padding: EdgeInsets.all(AppSpacing.x3l),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              size: 40,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),
          Text(
            'Email Sent',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Check your inbox for the password reset link. Once you have reset your password, return to the login screen.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: AppSpacing.x3l),
          AnimatedButton(
            onPressed: () => Navigator.pop(context),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            child: const Text('Back to Login', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
