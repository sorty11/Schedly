import 'package:flutter/material.dart';
import '../theme/theme.dart';
import '../widgets/schedly_text_field.dart';
import '../widgets/animations/animated_button.dart';
import '../utils/responsive_utils.dart';
import 'admin_session.dart';

class AdminAuthSheet extends StatefulWidget {
  final VoidCallback? onSuccess;
  
  const AdminAuthSheet({super.key, this.onSuccess});

  @override
  State<AdminAuthSheet> createState() => _AdminAuthSheetState();
}

class _AdminAuthSheetState extends State<AdminAuthSheet> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _verify() {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorText = null;
    });

    // Simulate network delay to prevent brute-forcing
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      if (_passwordController.text.trim() == 'schedly11') {
        AdminSession.isAuthenticated = true;
        Navigator.pop(context); // Close the sheet
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        }
      } else {
        setState(() {
          _loading = false;
          _errorText = 'Incorrect Master Password';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: ResponsiveUtils.constrainedFormBox(
            context,
            maxWidth: 500,
            child: Padding(
              padding: ResponsiveUtils.getBottomSheetMargin(context).copyWith(top: AppSpacing.x2l, bottom: AppSpacing.x2l),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Icon(
                      Icons.admin_panel_settings_rounded,
                      size: 48,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Admin Authentication',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Please enter the master password to access system administration tools.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        color: semanticColors.onSurfaceMuted,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.x2l),

                    // Form
                    if (_errorText != null) ...[
                      Text(
                        _errorText!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    SchedlyTextField(
                      controller: _passwordController,
                      labelText: 'Master Password',
                      obscureText: true,
                      prefixIcon: Icons.lock_rounded,
                      onFieldSubmitted: (_) => _verify(),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Password is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.x2l),
                    
                    AnimatedButton(
                      onPressed: _loading ? null : _verify,
                      isLoading: _loading,
                      child: const Text('Access Admin Tools'),
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
