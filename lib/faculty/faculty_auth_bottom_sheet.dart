import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/theme.dart';
import '../app_settings.dart';
import '../user_roles.dart';
import '../widgets/animations/staggered_list_item.dart';
import '../widgets/animations/animated_button.dart';
import '../widgets/animations/animated_icon_button.dart';
import '../widgets/app_dialogs.dart';
import 'faculty_setup_wizard.dart';
import 'faculty_home_page.dart';
import '../services/notification_service.dart';
import '../services/faculty_auth_service.dart';

class FacultyAuthBottomSheet extends StatefulWidget {
  const FacultyAuthBottomSheet({super.key});

  @override
  State<FacultyAuthBottomSheet> createState() => _FacultyAuthBottomSheetState();
}

class _FacultyAuthBottomSheetState extends State<FacultyAuthBottomSheet> {
  bool _showAuth = false;
  final _nameController = TextEditingController();
  final _masterPasswordController = TextEditingController();

  bool _loading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _masterPasswordController.dispose();
    super.dispose();
  }

  InputDecoration _modernDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
      filled: true,
      fillColor: Theme.of(context).colorScheme.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
      ),
      labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
      floatingLabelStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600),
    );
  }

  Future<void> _authenticate() async {
    final name = _nameController.text.trim();
    final masterPwd = _masterPasswordController.text.trim();

    if (name.isEmpty || masterPwd.isEmpty) {
      AppDialogs.showError(
        context: context,
        title: 'Missing Details',
        message: 'Please enter your Name and the Master Password.',
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final needsSetup = await FacultyAuthService.elevateToFaculty(
        name: name,
        masterPassword: masterPwd,
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();

      if (needsSetup) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const FacultySetupWizard()),
        );
      } else {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const FacultyHomePage()),
          (_) => false,
        );
      }
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showError(
        context: context,
        title: 'Authentication Failed',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _buildIntroPage() {
    return SingleChildScrollView(
      key: const ValueKey('intro'),
      padding: EdgeInsets.only(
        left: AppSpacing.x2l,
        right: AppSpacing.x2l,
        top: AppSpacing.x2l,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),
          const Text(
            'Faculty Portal',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Access your combined timetable and manage classes',
            style: TextStyle(fontSize: 15, color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.x3l),
          
          StaggeredListItem(index: 1, child: _buildFeatureRow(Icons.event_available_rounded, 'Consolidated Timetable', 'View classes across multiple divisions')),
          StaggeredListItem(index: 2, child: _buildFeatureRow(Icons.cancel_schedule_send_rounded, 'Manage Lectures', 'Cancel or add extra lectures')),
          StaggeredListItem(index: 3, child: _buildFeatureRow(Icons.campaign_rounded, 'Announcements', 'Send updates to your assigned divisions')),
          
          const SizedBox(height: AppSpacing.x2l),
          StaggeredListItem(
            index: 4,
            child: AnimatedButton(
              onPressed: () {
                setState(() => _showAuth = true);
              },
              child: const Text('Continue to Authentication'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String title, String subtitle) {
    return Padding(
      padding: EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.7), fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthPage() {
    return SingleChildScrollView(
      key: const ValueKey('auth'),
      padding: EdgeInsets.only(
        left: AppSpacing.x2l,
        right: AppSpacing.x2l,
        top: AppSpacing.x2l,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),
          Row(
            children: [
              AnimatedIconButton(
                onPressed: () => setState(() => _showAuth = false),
                icon: const Icon(Icons.arrow_back_rounded),
                padding: 0,
              ),
              const SizedBox(width: AppSpacing.lg),
              Container(
                padding: EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.school_rounded, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: AppSpacing.lg),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Faculty Login',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      'Secure Authentication Required',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          StaggeredListItem(
            index: 1,
            child: TextField(
              controller: _nameController,
              decoration: _modernDecoration('Full Name', Icons.person_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          
          StaggeredListItem(
            index: 2,
            child: TextField(
              controller: _masterPasswordController,
              obscureText: true,
              decoration: _modernDecoration('Master Password', Icons.admin_panel_settings_rounded),
            ),
          ),
          const SizedBox(height: AppSpacing.x2l),

          StaggeredListItem(
            index: 3,
            child: AnimatedButton(
              onPressed: _loading ? null : _authenticate,
              isLoading: _loading,
              child: const Text('Access Faculty Portal'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.x2l)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.85),
            borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.x2l)),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.05, 0.0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: _showAuth ? _buildAuthPage() : _buildIntroPage(),
          ),
        ),
      ),
    );
  }
}
