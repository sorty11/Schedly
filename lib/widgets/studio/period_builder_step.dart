import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/studio_state.dart';
import '../../theme/theme.dart';
import 'bottom_continue_button.dart';
import 'time_wheel_picker.dart';

class PeriodBuilderStep extends StatefulWidget {
  final List<PeriodDef> periods;
  final ValueChanged<List<PeriodDef>> onChanged;
  final VoidCallback onContinue;

  const PeriodBuilderStep({
    super.key,
    required this.periods,
    required this.onChanged,
    required this.onContinue,
  });

  @override
  State<PeriodBuilderStep> createState() => _PeriodBuilderStepState();
}

class _PeriodBuilderStepState extends State<PeriodBuilderStep> {
  late List<PeriodDef> _periods;
  String? _errorMessage;
  Set<String> _errorPeriodIds = {};

  @override
  void initState() {
    super.initState();
    _periods = List.from(widget.periods);
    if (_periods.isEmpty) {
      _periods = PeriodTemplates.nmims(); // prefill if empty
    }
    _validate();
  }

  void _update() {
    _validate();
    widget.onChanged(_periods);
  }

  void _validate() {
    _errorPeriodIds.clear();
    _errorMessage = null;
    
    if (_periods.isEmpty) {
      _errorMessage = 'Add at least one period.';
      setState(() {});
      return;
    }

    // Sort by start time for overlap checking visually
    final sorted = List<PeriodDef>.from(_periods)..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    
    final names = <String>{};

    for (int i = 0; i < sorted.length; i++) {
      final p = sorted[i];
      
      // End before start
      if (p.endMinutes <= p.startMinutes) {
        _errorPeriodIds.add(p.id);
        _errorMessage = 'End time must be after start time.';
      }

      // Duplicate names
      if (names.contains(p.name.trim().toLowerCase())) {
        _errorPeriodIds.add(p.id);
        _errorMessage = 'Duplicate period names are not allowed.';
      }
      names.add(p.name.trim().toLowerCase());

      // Overlap
      if (i > 0) {
        final prev = sorted[i - 1];
        if (p.startMinutes < prev.endMinutes) {
          _errorPeriodIds.add(p.id);
          _errorPeriodIds.add(prev.id);
          _errorMessage = 'Periods cannot overlap.';
        }
      }
    }
    
    setState(() {});
  }

  void _addPeriod(PeriodKind kind) {
    HapticFeedback.selectionClick();
    int start = 9 * 60; // 9 AM
    int end = 10 * 60; // 10 AM
    
    if (_periods.isNotEmpty) {
      start = _periods.last.endMinutes;
      end = start + 60;
    }

    String name = 'Period ${_periods.where((p) => p.kind == PeriodKind.lecture).length + 1}';
    if (kind == PeriodKind.breakTime) name = 'Break';
    if (kind == PeriodKind.lunch) name = 'Lunch';

    setState(() {
      _periods.add(PeriodDef(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: name,
        startMinutes: start,
        endMinutes: end,
        kind: kind,
      ));
    });
    _update();
  }

  void _duplicatePeriod(int index) {
    HapticFeedback.selectionClick();
    final p = _periods[index];
    setState(() {
      _periods.insert(index + 1, PeriodDef(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '${p.name} (Copy)',
        startMinutes: p.endMinutes,
        endMinutes: p.endMinutes + p.durationMinutes,
        kind: p.kind,
      ));
    });
    _update();
  }

  void _deletePeriod(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _periods.removeAt(index);
    });
    _update();
  }

  void _loadTemplate(List<PeriodDef> template) {
    HapticFeedback.selectionClick();
    setState(() {
      _periods = template.map((p) => p.copyWith()).toList();
    });
    _update();
  }

  String _formatTime(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '$hour12:${m.toString().padLeft(2, '0')} $suffix';
  }

  Future<void> _pickTime(int index, bool isStart) async {
    final p = _periods[index];
    final initialMins = isStart ? p.startMinutes : p.endMinutes;
    final initialTime = TimeOfDay(hour: initialMins ~/ 60, minute: initialMins % 60);

    final selected = await showTimeWheelPicker(context, initialTime: initialTime);
    if (selected != null) {
      final mins = selected.hour * 60 + selected.minute;
      setState(() {
        if (isStart) {
          _periods[index] = p.copyWith(startMinutes: mins);
        } else {
          _periods[index] = p.copyWith(endMinutes: mins);
        }
      });
      _update();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return Column(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(AppSpacing.x2l, AppSpacing.x2l, AppSpacing.x2l, AppSpacing.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Period Schedule',
                            style: GoogleFonts.outfit(
                                fontSize: 24, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Define timings once for the whole week.',
                            style: GoogleFonts.inter(
                                fontSize: 14, color: sem.onSurfaceMuted),
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (ctx) => _TemplateSelectorSheet(
                            onSelect: (t) {
                              Navigator.pop(ctx);
                              _loadTemplate(t);
                            },
                          ),
                        );
                      },
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: const Text('Template'),
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      ),
                    ),
                  ],
                ),
              ),

              // Error Banner
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _errorMessage != null
                    ? Container(
                        margin: EdgeInsets.symmetric(horizontal: AppSpacing.x2l, vertical: AppSpacing.sm),
                        padding: EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_rounded, color: cs.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_errorMessage!,
                                  style: GoogleFonts.inter(
                                      color: cs.error, fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),

              // List
              Expanded(
                child: ReorderableListView.builder(
                  padding: EdgeInsets.fromLTRB(AppSpacing.x2l, AppSpacing.sm, AppSpacing.x2l, 120),
                  itemCount: _periods.length,
                  onReorder: (oldIdx, newIdx) {
                    setState(() {
                      if (oldIdx < newIdx) newIdx -= 1;
                      final item = _periods.removeAt(oldIdx);
                      _periods.insert(newIdx, item);
                    });
                    _update();
                  },
                  proxyDecorator: (child, index, animation) {
                    return Material(
                      elevation: 8,
                      color: Colors.transparent,
                      child: child,
                    );
                  },
                  itemBuilder: (context, index) {
                    final p = _periods[index];
                    final hasError = _errorPeriodIds.contains(p.id);

                    return Padding(
                      key: ValueKey(p.id),
                      padding: EdgeInsets.only(bottom: AppSpacing.md),
                      child: _PeriodCard(
                        period: p,
                        hasError: hasError,
                        formatTime: _formatTime,
                        onNameChanged: (v) {
                          setState(() => _periods[index] = p.copyWith(name: v));
                          _update();
                        },
                        onKindChanged: (v) {
                          setState(() => _periods[index] = p.copyWith(kind: v));
                          _update();
                        },
                        onPickStart: () => _pickTime(index, true),
                        onPickEnd: () => _pickTime(index, false),
                        onDuplicate: () => _duplicatePeriod(index),
                        onDelete: () => _deletePeriod(index),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),

        // Bottom Bar with Add Buttons
        Container(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? sem.surfaceElevated
                : cs.surface,
            border: Border(top: BorderSide(color: sem.borderSubtle)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: () => _addPeriod(PeriodKind.lecture),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Lecture'),
              ),
              TextButton.icon(
                onPressed: () => _addPeriod(PeriodKind.breakTime),
                icon: const Icon(Icons.coffee_rounded, size: 18),
                label: const Text('Break'),
              ),
              TextButton.icon(
                onPressed: () => _addPeriod(PeriodKind.lunch),
                icon: const Icon(Icons.restaurant_rounded, size: 18),
                label: const Text('Lunch'),
              ),
            ],
          ),
        ),

        BottomContinueButton(
          enabled: _errorMessage == null && _periods.isNotEmpty,
          onTap: widget.onContinue,
          label: 'Continue to Weekly Builder',
        ),
      ],
    );
  }
}

class _PeriodCard extends StatelessWidget {
  final PeriodDef period;
  final bool hasError;
  final String Function(int) formatTime;
  final ValueChanged<String> onNameChanged;
  final ValueChanged<PeriodKind> onKindChanged;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;

  const _PeriodCard({
    required this.period,
    required this.hasError,
    required this.formatTime,
    required this.onNameChanged,
    required this.onKindChanged,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onDuplicate,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color cardColor = isDark ? sem.surfaceElevated2 : cs.surface;
    Color borderColor = sem.borderSubtle;
    
    if (hasError) {
      cardColor = cs.errorContainer.withValues(alpha: 0.3);
      borderColor = cs.error;
    } else if (period.isBreak) {
      cardColor = cs.secondaryContainer.withValues(alpha: 0.3);
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor, width: hasError ? 2 : 1),
      ),
      padding: EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          const Padding(
            padding: EdgeInsets.only(top: AppSpacing.md, right: AppSpacing.sm),
            child: Icon(Icons.drag_indicator_rounded, color: Colors.grey),
          ),
          
          Expanded(
            child: Column(
              children: [
                // Top row: Type dropdown & Actions
                Row(
                  children: [
                    Container(
                      height: 32,
                      padding: EdgeInsets.symmetric(horizontal: AppSpacing.md),
                      decoration: BoxDecoration(
                        color: sem.surfaceElevated,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<PeriodKind>(
                          value: period.kind,
                          icon: const Icon(Icons.arrow_drop_down, size: 18),
                          isDense: true,
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onSurface),
                          onChanged: (k) {
                            if (k != null) onKindChanged(k);
                          },
                          items: const [
                            DropdownMenuItem(value: PeriodKind.lecture, child: Text('Lecture')),
                            DropdownMenuItem(value: PeriodKind.breakTime, child: Text('Break')),
                            DropdownMenuItem(value: PeriodKind.lunch, child: Text('Lunch')),
                            DropdownMenuItem(value: PeriodKind.freePeriod, child: Text('Free Period')),
                          ],
                        ),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      onPressed: onDuplicate,
                      tooltip: 'Duplicate',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline_rounded, size: 18, color: cs.error),
                      onPressed: onDelete,
                      tooltip: 'Delete',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Name Input
                TextFormField(
                  initialValue: period.name,
                  onChanged: onNameChanged,
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                  decoration: InputDecoration(
                    labelText: 'Period Name',
                    contentPadding: EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Time Pickers
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: onPickStart,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
                          decoration: BoxDecoration(
                            border: Border.all(color: sem.borderSubtle),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Start', style: GoogleFonts.inter(fontSize: 10, color: sem.onSurfaceMuted)),
                              Text(formatTime(period.startMinutes), style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: onPickEnd,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm, horizontal: AppSpacing.md),
                          decoration: BoxDecoration(
                            border: Border.all(color: sem.borderSubtle),
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('End', style: GoogleFonts.inter(fontSize: 10, color: sem.onSurfaceMuted)),
                              Text(formatTime(period.endMinutes), style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TemplateSelectorSheet extends StatelessWidget {
  final ValueChanged<List<PeriodDef>> onSelect;

  const _TemplateSelectorSheet({required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? sem.surfaceElevated2 : cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 5,
                margin: EdgeInsets.only(bottom: AppSpacing.lg),
                decoration: BoxDecoration(
                  color: sem.borderSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text('Load Template', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.account_balance_rounded),
                title: const Text('NMIMS (Mumbai)'),
                subtitle: const Text('9:15 AM - 4:15 PM'),
                onTap: () => onSelect(PeriodTemplates.nmims()),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_rounded),
                title: const Text('JNTUH'),
                subtitle: const Text('9:20 AM - 3:50 PM'),
                onTap: () => onSelect(PeriodTemplates.jntuh()),
              ),
              ListTile(
                leading: const Icon(Icons.account_balance_rounded),
                title: const Text('Osmania University (OU)'),
                subtitle: const Text('9:00 AM - 3:00 PM'),
                onTap: () => onSelect(PeriodTemplates.ou()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
