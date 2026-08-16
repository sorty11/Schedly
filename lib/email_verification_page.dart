import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:schedly/main.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_button.dart';
import 'widgets/schedly_card.dart';
import 'services/authentication_service.dart';
import 'widgets/app_dialogs.dart';
import 'widgets/animations/animated_auth_background.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _checking = false;
  bool _resending = false;

  Future<void> _checkStatus() async {
    setState(() => _checking = true);
    final verified = await AuthenticationService.isEmailVerified();

    if (!mounted) return;
    setState(() => _checking = false);

    if (verified) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StartupRouter()),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email not verified yet. Please check your inbox.'),
        ),
      );
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _resending = true);
    try {
      await AuthenticationService.sendVerificationEmail();
      if (!mounted) return;
      AppDialogs.showSnackBar(
        context: context,
        message: 'Verification email sent! Check your inbox.',
      );
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showError(
        context: context,
        title: 'Error',
        message: e.toString(),
      );
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  Future<void> _signOut() async {
    await AuthenticationService.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const StartupRouter()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? 'your email';

    return AnimatedAuthBackground(
      isCenteredLogo: true,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('Verify Email'),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: _signOut,
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.x2l),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: SchedlyCard(
                variant: SchedlyCardVariant.elevated,
                padding: EdgeInsets.all(AppSpacing.x3l),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.mark_email_unread_rounded,
                        size: 40,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x2l),
                    Text(
                      'Verify your email',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'We sent a verification link to:\n$email',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x3l),
                    AnimatedButton(
                      onPressed: _checking ? null : _checkStatus,
                      isLoading: _checking,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      child: const Text(
                        'I have verified my email',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextButton.icon(
                      onPressed: _resending ? null : _resendEmail,
                      icon: _resending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh_rounded),
                      label: const Text('Resend Verification Email'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
