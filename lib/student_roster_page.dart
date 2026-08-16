import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'services/division_membership_service.dart';
import 'theme/theme.dart';
import 'widgets/animations/floating_empty_state.dart';
import 'app_settings.dart';
import 'user_roles.dart';
import 'widgets/app_dialogs.dart';
import 'widgets/schedly_card.dart';
import 'widgets/schedly_text_field.dart';
import 'widgets/dashboard_layout.dart';
import 'widgets/section_header.dart';

class StudentRosterPage extends StatefulWidget {
  final String division;

  const StudentRosterPage({super.key, required this.division});

  @override
  State<StudentRosterPage> createState() => _StudentRosterPageState();
}

class _StudentRosterPageState extends State<StudentRosterPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  bool _isLoading = true;
  List<Map<String, dynamic>> _roster = [];

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRoster() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final roster = await DivisionMembershipService.getSectionRoster(
        widget.division,
      );

      // Sort by roll number initially
      roster.sort((a, b) {
        final rollA = (a['profile']['rollNo'] as String?) ?? '';
        final rollB = (b['profile']['rollNo'] as String?) ?? '';
        return rollA.compareTo(rollB);
      });

      if (mounted) {
        setState(() {
          _roster = roster;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppDialogs.showError(
          context: context,
          title: 'Error',
          message: 'Failed to load class roster: $e',
        );
      }
    }
  }

  Future<void> _confirmRemoveStudent(Map<String, dynamic> studentData) async {
    final profile = studentData['profile'] as Map<String, dynamic>;
    final uid = studentData['uid'] as String;
    final name = profile['name'] as String? ?? 'Unknown Student';
    final rollNo = profile['rollNo'] as String? ?? 'Unknown Roll';
    final role = studentData['membership']['role'] as String? ?? 'Student';

    if (role == 'CR') {
      AppDialogs.showError(
        context: context,
        title: 'Action Denied',
        message: 'You cannot remove another Class Representative.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Student'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to remove\n\n$name\n\nfrom\n\n${widget.division}?',
            ),
            const SizedBox(height: AppSpacing.lg),
            const Text('This action will:'),
            const Text('✓ Remove the student from the class roster'),
            const Text('✓ Revoke access to this section'),
            const Text('✓ Stop receiving section notifications'),
            const Text('✓ End their current section session'),
            const SizedBox(height: AppSpacing.lg),
            const Text(
              'The student\'s account and historical data will NOT be deleted.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove Student'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final reason = await showDialog<String>(
        context: context,
        builder: (ctx) {
          final controller = TextEditingController();
          return AlertDialog(
            title: const Text('Reason (Optional)'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'e.g., Transferred, Dropped out',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, controller.text),
                child: const Text('Submit'),
              ),
            ],
          );
        },
      );

      if (reason != null) {
        _removeStudent(uid, name, reason);
      }
    }
  }

  Future<void> _removeStudent(
    String targetUid,
    String targetName,
    String reason,
  ) async {
    setState(() => _isLoading = true);
    try {
      final crUid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
      final crName = AppSettings.studentName ?? 'CR';

      await DivisionMembershipService.removeStudent(
        targetUid: targetUid,
        sectionId: widget.division,
        crUid: crUid,
        targetName: targetName,
        crName: crName,
        reason: reason,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$targetName was removed from the section.')),
      );

      await _loadRoster();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to remove student. Please try again.'),
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Set<String> _selectedUids = {};
  bool _isSelectionMode = false;

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedUids.clear();
      }
    });
  }

  void _toggleStudentSelection(String uid) {
    setState(() {
      if (_selectedUids.contains(uid)) {
        _selectedUids.remove(uid);
      } else {
        _selectedUids.add(uid);
      }
    });
  }

  Future<void> _removeSelected() async {
    if (_selectedUids.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Remove ${_selectedUids.length} Students?',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w700),
        ),
        content: const Text(
          'Are you sure you want to remove the selected students from the section?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // In a real app, you would have a bulk remove API.
      // For now, we simulate bulk remove by looping (or just notifying).
      setState(() => _isLoading = true);
      try {
        final crUid = FirebaseAuth.instance.currentUser?.uid ?? 'unknown';
        final crName = AppSettings.studentName ?? 'CR';

        for (final uid in _selectedUids) {
          final student = _roster.firstWhere((s) => s['uid'] == uid);
          final profile = student['profile'] as Map<String, dynamic>;
          final name = profile['name'] as String? ?? 'Unknown Student';

          await DivisionMembershipService.removeStudent(
            targetUid: uid,
            sectionId: widget.division,
            crUid: crUid,
            targetName: name,
            crName: crName,
            reason: 'Bulk removal',
          );
        }

        if (mounted) {
          AppDialogs.showSnackBar(
            context: context,
            message: 'Removed ${_selectedUids.length} students.',
          );
          _isSelectionMode = false;
          _selectedUids.clear();
          await _loadRoster();
        }
      } catch (e) {
        if (mounted) {
          AppDialogs.showSnackBar(
            context: context,
            message: 'Failed to remove some students.',
            isError: true,
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final filteredRoster = _roster.where((s) {
      if (_searchQuery.isEmpty) return true;
      final profile = s['profile'] as Map<String, dynamic>;
      final name = (profile['name'] as String? ?? '').toLowerCase();
      final rollNo = (profile['rollNo'] as String? ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || rollNo.contains(query);
    }).toList();

    final isCR = AppSettings.currentRole == UserRole.cr;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.background,
      floatingActionButton: _isSelectionMode && _selectedUids.isNotEmpty
          ? FloatingActionButton.extended(
              onPressed: _removeSelected,
              backgroundColor: sem.error,
              icon: const Icon(
                Icons.person_remove_rounded,
                color: Colors.white,
              ),
              label: Text(
                'Remove ',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadRoster,
        child: Workspace(
          children: [
            SectionHeader(
              title: _isSelectionMode ? ' Selected' : 'Class Roster',
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!_isSelectionMode)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        ' Students',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  if (isCR && filteredRoster.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      icon: Icon(
                        _isSelectionMode
                            ? Icons.close_rounded
                            : Icons.checklist_rounded,
                      ),
                      tooltip: _isSelectionMode
                          ? 'Cancel Selection'
                          : 'Select Multiple',
                      onPressed: _toggleSelectionMode,
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.x2l),
              child: SchedlyTextField(
                controller: _searchController,
                hintText: 'Search by Name or Roll No...',
                prefixIcon: Icons.search_rounded,
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSpacing.x3l),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (filteredRoster.isEmpty)
              const Center(
                child: FloatingEmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No Students Found',
                  subtitle:
                      'Could not find any active students matching your query.',
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredRoster.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (context, index) {
                  final student = filteredRoster[index];
                  final profile = student['profile'] as Map<String, dynamic>;
                  final name = profile['name'] as String? ?? 'Unknown';
                  final rollNo = profile['rollNo'] as String? ?? '-';
                  final role =
                      student['membership']['role'] as String? ?? 'Student';
                  final uid = student['uid'] as String;

                  final isCRRole = role == 'CR';
                  final isSelected = _selectedUids.contains(uid);

                  return SchedlyCard(
                    variant: isSelected
                        ? SchedlyCardVariant.tinted
                        : SchedlyCardVariant.elevated,
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    onTap: _isSelectionMode && !isCRRole
                        ? () => _toggleStudentSelection(uid)
                        : null,
                    child: Row(
                      children: [
                        if (_isSelectionMode && !isCRRole)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                            ),
                            child: Icon(
                              isSelected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: isSelected
                                  ? colorScheme.primary
                                  : sem.onSurfaceFaint,
                            ),
                          ),
                        Container(
                          width: 48,
                          height: 48,
                          margin: const EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: isCRRole
                                ? colorScheme.primary.withValues(alpha: 0.15)
                                : colorScheme.secondary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: TextStyle(
                              fontFamily: 'Outfit',
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: isCRRole
                                  ? colorScheme.primary
                                  : colorScheme.secondary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    rollNo,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      color: sem.onSurfaceMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (isCRRole) ...[
                                    const SizedBox(width: AppSpacing.sm),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Class Rep',
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isCR && !_isSelectionMode)
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert_rounded,
                              color: sem.onSurfaceMuted,
                            ),
                            color: isDark
                                ? sem.surfaceElevated2
                                : colorScheme.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            onSelected: (value) {
                              if (value == 'remove') {
                                _confirmRemoveStudent(student);
                              }
                            },
                            itemBuilder: (context) => [
                              const PopupMenuItem(
                                value: 'profile',
                                child: Text('View Profile'),
                              ),
                              PopupMenuItem(
                                value: 'remove',
                                enabled: !isCRRole,
                                child: Text(
                                  'Remove from Division',
                                  style: TextStyle(
                                    color: isCRRole
                                        ? Theme.of(context).disabledColor
                                        : sem.error,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}
