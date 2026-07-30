import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../app_settings.dart';
import '../theme/theme.dart';
import '../widgets/schedly_card.dart';
import '../widgets/animations/animated_button.dart';
import '../widgets/app_dialogs.dart';

class CRPasswordManagementPage extends StatefulWidget {
  final String division;

  const CRPasswordManagementPage({super.key, required this.division});

  @override
  State<CRPasswordManagementPage> createState() => _CRPasswordManagementPageState();
}

class _CRPasswordManagementPageState extends State<CRPasswordManagementPage> {
  bool _isLoading = true;
  String? _crPassword;
  String? _srPassword;
  DateTime? _lastUpdatedAt;
  String? _lastUpdatedBy;

  @override
  void initState() {
    super.initState();
    _fetchPasswords();
  }

  Future<void> _fetchPasswords() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('sections').doc(widget.division).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _crPassword = data['crPassword'];
          _srPassword = data['srPassword'];
          if (data['passwordLastUpdatedAt'] != null) {
            _lastUpdatedAt = (data['passwordLastUpdatedAt'] as Timestamp).toDate();
          }
          _lastUpdatedBy = data['passwordLastUpdatedBy'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        AppDialogs.showError(context: context, title: 'Error', message: 'Failed to load passwords: $e');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showChangePasswordSheet(String role) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ChangePasswordSheet(
        role: role,
        division: widget.division,
        currentStoredPassword: role == 'CR' ? _crPassword! : _srPassword!,
        onSuccess: _fetchPasswords,
      ),
    );
  }

  Widget _buildPasswordCard(String title, String role, String? password) {
    final semanticColors = Theme.of(context).extension<AppSemanticColors>()!;
    
    return SchedlyCard(
      variant: SchedlyCardVariant.elevated,
      padding: EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(role == 'CR' ? Icons.security_rounded : Icons.key_rounded, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Current Password',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: semanticColors.onSurfaceMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '••••••••',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_lastUpdatedAt != null) ...[
            Row(
              children: [
                Icon(Icons.history_rounded, size: 14, color: semanticColors.onSurfaceMuted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Last updated ${DateFormat('MMM d, y, h:mm a').format(_lastUpdatedAt!)} by ${_lastUpdatedBy ?? 'Unknown'}',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: semanticColors.onSurfaceMuted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          SizedBox(
            width: double.infinity,
            child: AnimatedButton(
              onPressed: _isLoading || password == null ? null : () => _showChangePasswordSheet(role),
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              foregroundColor: Theme.of(context).colorScheme.primary,
              child: const Text('Change Password', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Role Password Management', style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  _buildPasswordCard('CR Password', 'CR', _crPassword),
                  const SizedBox(height: AppSpacing.lg),
                  _buildPasswordCard('SR Password', 'SR', _srPassword),
                ],
              ),
            ),
    );
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  final String role;
  final String division;
  final String currentStoredPassword;
  final VoidCallback onSuccess;

  const _ChangePasswordSheet({
    required this.role,
    required this.division,
    required this.currentStoredPassword,
    required this.onSuccess,
  });

  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _currentPwdController = TextEditingController();
  final _newPwdController = TextEditingController();
  final _confirmPwdController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _currentPwdController.dispose();
    _newPwdController.dispose();
    _confirmPwdController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;
    
    final currentInput = _currentPwdController.text.trim();
    final newPwd = _newPwdController.text.trim();

    if (currentInput != widget.currentStoredPassword) {
      AppDialogs.showError(context: context, title: 'Validation Error', message: 'Current password is incorrect.');
      return;
    }

    if (newPwd == widget.currentStoredPassword) {
      AppDialogs.showError(context: context, title: 'Validation Error', message: 'New password must be different from the old password.');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Confirm Change', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to change the ${widget.role} password?\n\nStudents using the old password will no longer be able to verify.',
          style: GoogleFonts.inter(),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSaving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      final fieldToUpdate = widget.role == 'CR' ? 'crPassword' : 'srPassword';
      
      await FirebaseFirestore.instance.collection('sections').doc(widget.division).update({
        fieldToUpdate: newPwd,
        'passwordLastUpdatedAt': FieldValue.serverTimestamp(),
        'passwordLastUpdatedBy': '${AppSettings.studentName} (${AppSettings.studentRollNo})',
      });

      if (!mounted) return;
      AppDialogs.showSnackBar(context: context, message: '${widget.role} password updated successfully.');
      widget.onSuccess();
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showError(context: context, title: 'Error', message: 'Failed to update password. Please check your connection.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    return Container(
      margin: const EdgeInsets.only(top: kToolbarHeight),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.x2l)),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.xl, AppSpacing.lg, AppSpacing.xl + bottomInset),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Theme.of(context).dividerColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    'Change ${widget.role} Password',
                    style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: AppSpacing.x2l),
                  TextFormField(
                    controller: _currentPwdController,
                    obscureText: _obscureCurrent,
                    decoration: InputDecoration(
                      labelText: 'Current Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureCurrent ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                        onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                      ),
                    ),
                    validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _newPwdController,
                    obscureText: _obscureNew,
                    decoration: InputDecoration(
                      labelText: 'New Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureNew ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                        onPressed: () => setState(() => _obscureNew = !_obscureNew),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Required';
                      if (val.trim().length < 6) return 'Must be at least 6 characters';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  TextFormField(
                    controller: _confirmPwdController,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      labelText: 'Confirm New Password',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      suffixIcon: IconButton(
                        icon: Icon(_obscureConfirm ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                        onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Required';
                      if (val.trim() != _newPwdController.text.trim()) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: AppSpacing.x3l),
                  AnimatedButton(
                    onPressed: _isSaving ? null : _handleSave,
                    isLoading: _isSaving,
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold)),
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
