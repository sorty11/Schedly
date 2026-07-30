import 'package:flutter/material.dart';
import 'package:schedly/services/authentication_service.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_button.dart';
import 'widgets/app_dialogs.dart';
import 'main.dart';

class AccountMigrationPage extends StatefulWidget {
  const AccountMigrationPage({super.key});

  @override
  State<AccountMigrationPage> createState() => _AccountMigrationPageState();
}

class _AccountMigrationPageState extends State<AccountMigrationPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _loading = false;
  bool _obscurePassword = true;

  Future<void> _migrate() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      await AuthenticationService.linkAnonymousAccount(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      // After linking, the user is an Email/Password user.
      // Redirect to StartupRouter which will check email verification status.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const StartupRouter()),
      );
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showError(
        context: context,
        title: 'Security Update Failed',
        message: e.toString().replaceAll(RegExp(r'\[.*\]\s*'), ''),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Security Update'),
        automaticallyImplyLeading: false, // Force them to complete this
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(AppSpacing.x2l),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.security_rounded,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: AppSpacing.x2l),
                  Text(
                    'Secure Your Account',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'We are upgrading our authentication system! Please provide an email address and create a password to secure your existing Schedly account.\n\nYour attendance, timetable, and settings will remain completely intact.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: AppSpacing.x3l),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      prefixIcon: Icon(Icons.email_rounded),
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || !val.contains('@') ? 'Enter a valid email' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Create Password',
                      prefixIcon: const Icon(Icons.lock_rounded),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Password is required';
                      if (val.length < 8) return 'Minimum 8 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.x3l),
                  AnimatedButton(
                    onPressed: _loading ? null : _migrate,
                    isLoading: _loading,
                    child: const Text('Secure Account & Continue'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
