import '../services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'widgets/animations/floating_empty_state.dart';

import 'home_page.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'timetable_manager.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_button.dart';
import 'widgets/animations/animated_card.dart';
import 'widgets/app_dialogs.dart';

class RoleVerificationPage extends StatefulWidget {
  final String division;
  final String role;

  const RoleVerificationPage({
    super.key,
    required this.division,
    required this.role,
  });

  @override
  State<RoleVerificationPage> createState() => _RoleVerificationPageState();
}

class _RoleVerificationPageState extends State<RoleVerificationPage> {
  final passwordController = TextEditingController();

  bool loading = false;
  bool _passwordVerified = false;
  
  List<String> _uniqueSubjects = [];

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() => loading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('sections')
          .doc(widget.division)
          .get();

      if (!doc.exists) {
        throw Exception('Role configuration not found');
      }

      final data = doc.data()!;
      final savedPassword = widget.role == 'CR' ? data['crPassword'] : data['srPassword'];

      if (passwordController.text != savedPassword) {
        throw Exception('Incorrect password');
      }

      if (widget.role == 'CR') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_division', widget.division); await NotificationService.updateDivisionSubscription(widget.division);
        await AppSettings.saveRole(UserRole.cr);

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => HomePage(division: widget.division)),
          (_) => false,
        );
      } else {
        // SR: Fetch unique root subjects from timetable
        final subjects = await TimetableManager.getUniqueSubjects(division: widget.division);

        if (!mounted) return;
        setState(() {
          _passwordVerified = true;
          _uniqueSubjects = subjects;
          loading = false;
        });
        return;
      }
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showError(
        context: context,
        title: 'Verification Failed',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    }

    if (mounted) setState(() => loading = false);
  }

  // Replaced by _attemptClaim and _performClaim

  Future<void> _attemptClaim(String subject) async {
    setState(() => loading = true);
    
    try {
      final assignmentId = subject.toLowerCase().replaceAll(' ', '_');
      final assignmentRef = FirebaseFirestore.instance
          .collection('sections')
          .doc(widget.division)
          .collection('sr_assignments')
          .doc(assignmentId);

      final assignmentDoc = await assignmentRef.get();
      List<dynamic> activeSRs = [];
      if (assignmentDoc.exists && assignmentDoc.data()?['srs'] is List) {
        activeSRs = List.from(assignmentDoc.data()!['srs']);
      }
      
      if (activeSRs.length >= 2) {
        if (!mounted) return;
        setState(() => loading = false);
        
        final userToReplace = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Role Fully Claimed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('This subject already has two active Subject Representatives. Select an SR to transfer their role to yourself:'),
                const SizedBox(height: 16),
                ...activeSRs.map((sr) => ListTile(
                  title: Text(sr.toString()),
                  trailing: const Icon(Icons.swap_horiz_rounded),
                  onTap: () => Navigator.pop(context, sr.toString()),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                  tileColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                )),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
        
        if (userToReplace != null) {
          await _performClaim(subject, activeSRs, userToReplace);
        }
      } else {
        await _performClaim(subject, activeSRs, null);
      }
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showError(
        context: context,
        title: 'Failed to claim role',
        message: e.toString().replaceAll('Exception: ', ''),
      );
      setState(() => loading = false);
    }
  }

  Future<void> _performClaim(String subject, List<dynamic> activeSRs, String? userToReplace) async {
    setState(() => loading = true);
    try {
      final assignmentId = subject.toLowerCase().replaceAll(' ', '_');
      final assignmentRef = FirebaseFirestore.instance
          .collection('sections')
          .doc(widget.division)
          .collection('sr_assignments')
          .doc(assignmentId);

      final studentName = AppSettings.studentName ?? 'Unknown SR';
      final studentRoll = AppSettings.studentRollNo ?? '';
      final myIdentity = '$studentName ($studentRoll)';

      if (userToReplace != null) {
        activeSRs.remove(userToReplace);
      }
      
      if (!activeSRs.contains(myIdentity)) {
        activeSRs.add(myIdentity);
      }
      
      await assignmentRef.set({
        'srs': activeSRs,
        'timestamp': FieldValue.serverTimestamp(),
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_division', widget.division); await NotificationService.updateDivisionSubscription(widget.division);
      await AppSettings.saveRole(UserRole.sr);
      await AppSettings.saveSRSection(sectionId: widget.division);
      
      // We pass null for component and batch because the SR now manages the entire root subject
      await AppSettings.saveSRDetails(
        division: AppSettings.division ?? widget.division,
        subject: subject,
        component: null,
        batch: null,
      );

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomePage(division: widget.division)),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showError(
        context: context,
        title: 'Failed to assign SR',
        message: e.toString().replaceAll('Exception: ', ''),
      );
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.role} Verification'),
      ),
      body: _passwordVerified && widget.role == 'SR'
          ? _buildSubjectPicker()
          : Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: _buildPasswordStep(),
            ),
    );
  }

  Widget _buildPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Division: ${widget.division}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: InputDecoration(
            labelText: '${widget.role} Password',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: AnimatedButton(
            onPressed: loading ? null : _verify,
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Verify', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildSubjectPicker() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sections')
          .doc(widget.division)
          .collection('sr_assignments')
          .snapshots(),
      builder: (context, snapshot) {
        final assignments = <String, List<dynamic>>{};
        if (snapshot.hasData) {
          for (final doc in snapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['srs'] is List) {
              assignments[doc.id] = List.from(data['srs']);
            }
          }
        }

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.all(AppSpacing.x2l),
              sliver: SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select your assignment',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Division: ${widget.division}',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_uniqueSubjects.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: FloatingEmptyState(
                    icon: Icons.menu_book_rounded,
                    title: 'No Subjects',
                    subtitle: 'No academic subjects found.',
                  ),
                ),
              )
            else
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final subject = _uniqueSubjects[index];
                    final assignmentId = subject.toLowerCase().replaceAll(' ', '_');
                    final srs = assignments[assignmentId] ?? [];
                    final isFullyClaimed = srs.length >= 2;
                    final displayStatus = srs.isEmpty 
                        ? 'Available' 
                        : srs.length == 1 
                            ? '1/2 Claimed' 
                            : 'Fully Claimed';
                    
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.x2l, vertical: AppSpacing.sm),
                      child: AnimatedCard(
                        borderRadius: AppRadius.xl,
                        onTap: loading ? null : () => _attemptClaim(subject),
                        backgroundColor: isFullyClaimed 
                            ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
                            : Theme.of(context).colorScheme.surface,
                        child: Container(
                          padding: EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.xl),
                            border: Border.all(
                              color: isFullyClaimed
                                  ? Theme.of(context).colorScheme.outlineVariant
                                  : Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      subject,
                                      style: GoogleFonts.outfit(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: isFullyClaimed ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      displayStatus,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: isFullyClaimed 
                                          ? Theme.of(context).colorScheme.onSurfaceVariant 
                                          : Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isFullyClaimed)
                                Icon(Icons.lock_rounded, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant)
                              else
                                Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Theme.of(context).colorScheme.primary),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  childCount: _uniqueSubjects.length,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.x6l)),
          ],
        );
      },
    );
  }
}