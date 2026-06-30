import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/studio_state.dart';
import '../../theme/theme.dart';
import 'period_config_sheet.dart';
import 'bottom_continue_button.dart';

class WeeklyBuilderStep extends StatefulWidget {
  final StudioDraftConfig draft;
  final ValueChanged<StudioDraftConfig> onChanged;
  final VoidCallback onPublish;
  final bool isPublishing;

  const WeeklyBuilderStep({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onPublish,
    required this.isPublishing,
  });

  @override
  State<WeeklyBuilderStep> createState() => _WeeklyBuilderStepState();
}

class _WeeklyBuilderStepState extends State<WeeklyBuilderStep>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late StudioDraftConfig _draft;

  @override
  void initState() {
    super.initState();
    _draft = widget.draft;
    _draft.ensureSlotsInitialised();
    
    _tabController = TabController(length: _draft.selectedDays.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void didUpdateWidget(covariant WeeklyBuilderStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.draft != widget.draft) {
      _draft = widget.draft;
      _draft.ensureSlotsInitialised();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _update() {
    widget.onChanged(_draft);
  }

  String _formatTime(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    final suffix = h >= 12 ? 'PM' : 'AM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    return '$hour12:${m.toString().padLeft(2, '0')} $suffix';
  }

  Future<void> _openPeriodConfig(String day, String periodId) async {
    final periodIndex = _draft.periods.indexWhere((p) => p.id == periodId);
    final p = _draft.periods[periodIndex];
    final existingSlots = _draft.slots[day]?[p.id] ?? [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PeriodConfigSheet(
        period: p,
        initialSlots: existingSlots,
        onSave: (newSlots) {
          setState(() {
            _draft.slots[day] ??= {};
            if (newSlots.isEmpty) {
              _draft.slots[day]!.remove(p.id);
            } else {
              _draft.slots[day]![p.id] = newSlots;
            }
          });
          _update();
        },
      ),
    );
  }

  void _showSlotOptions(String day, String periodId, SlotState slot, int listIndex) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_rounded),
                title: const Text('Edit Lecture'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openPeriodConfig(day, periodId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_copy_rounded),
                title: const Text('Duplicate to Next Period'),
                onTap: () {
                  Navigator.pop(ctx);
                  final periodIndex = _draft.periods.indexWhere((p) => p.id == periodId);
                  if (periodIndex + 1 < _draft.periods.length) {
                    final nextPeriodId = _draft.periods[periodIndex + 1].id;
                    setState(() {
                      _draft.slots[day] ??= {};
                      _draft.slots[day]![nextPeriodId] ??= [];
                      _draft.slots[day]![nextPeriodId]!.add(slot.copyWith(periodId: nextPeriodId));
                    });
                    _update();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No next period available on this day.')));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.clear_all_rounded, color: Colors.red),
                title: const Text('Reset entire period', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  showDialog(
                    context: context,
                    builder: (dCtx) => AlertDialog(
                      title: const Text('Reset Period?'),
                      content: const Text('This will remove all lectures from this period.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                        FilledButton(
                          onPressed: () {
                            setState(() {
                              _draft.slots[day]![periodId] = [];
                            });
                            _update();
                            Navigator.pop(dCtx);
                          },
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  bool _allDaysComplete() {
    for (final day in _draft.selectedDays) {
      if (!_draft.isDayComplete(day)) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG: WeeklyBuilderStep build called. _draft.batches = ${_draft.batches}');
    final cs = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Top Progress Strip
        Container(
          color: isDark ? sem.surfaceElevated : cs.surface,
          child: Column(
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    ...List.generate(_draft.selectedDays.length, (index) {
                      final day = _draft.selectedDays[index];
                      final isComplete = _draft.isDayComplete(day);
                      final isSelected = _tabController.index == index;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _tabController.animateTo(index);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isComplete 
                              ? Colors.green.withValues(alpha: isDark ? 0.2 : 0.1)
                              : (isSelected ? cs.primary.withValues(alpha: 0.1) : Colors.transparent),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isComplete 
                                ? Colors.green 
                                : (isSelected ? cs.primary : sem.borderSubtle),
                            width: isSelected || isComplete ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isComplete) ...[
                                  const Icon(Icons.check_circle_rounded, color: Colors.green, size: 14),
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  day.substring(0, 3),
                                  style: GoogleFonts.inter(
                                    fontWeight: isSelected || isComplete ? FontWeight.w700 : FontWeight.w500,
                                    color: isComplete ? Colors.green : (isSelected ? cs.primary : sem.onSurfaceMuted),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${_draft.filledCount(day)} / ${_draft.academicPeriodCount}',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isComplete ? Colors.green : sem.onSurfaceMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    }),
                    const SizedBox(width: 16),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                      tooltip: 'Delete Draft',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (dCtx) => AlertDialog(
                            title: Text('Delete Draft?', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                            content: Text('This will permanently remove all unpublished timetable data.', style: GoogleFonts.inter()),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(dCtx), child: const Text('Cancel')),
                              TextButton(
                                onPressed: () async {
                                  Navigator.pop(dCtx);
                                  final prefs = await SharedPreferences.getInstance();
                                  final keys = prefs.getKeys().where((k) => k.startsWith('studio_draft_'));
                                  for (final k in keys) {
                                    await prefs.remove(k);
                                  }
                                  if (context.mounted) Navigator.pop(context); // Exit studio
                                },
                                child: Text('Delete Draft', style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Tab Views
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: _draft.selectedDays.map((day) {
              return _buildDayView(day, cs, sem);
            }).toList(),
          ),
        ),

        // Publish Button
        Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
          decoration: BoxDecoration(
            color: isDark ? sem.surfaceElevated : cs.surface,
            border: Border(top: BorderSide(color: sem.borderSubtle)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -4))],
          ),
          child: SafeArea(
            top: false,
            child: FilledButton.icon(
              onPressed: _allDaysComplete() && !widget.isPublishing ? widget.onPublish : null,
              icon: widget.isPublishing 
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.publish_rounded, size: 18),
              label: Text(widget.isPublishing ? 'Publishing...' : 'Publish Timetable', 
                  style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayView(String day, ColorScheme cs, AppSemanticColors sem) {
    final daySlots = _draft.slots[day] ?? {};
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final Set<int> skippedIndices = {};
    for (int pIdx = 0; pIdx < _draft.periods.length; pIdx++) {
      if (skippedIndices.contains(pIdx)) continue;
      final period = _draft.periods[pIdx];
      final periodLectures = daySlots[period.id] ?? [];
      int maxDuration = 1;
      for (final slot in periodLectures) {
        if (slot.durationPeriods > maxDuration) {
          maxDuration = slot.durationPeriods;
        }
      }
      if (maxDuration > 1) {
        for (int i = 1; i < maxDuration; i++) {
          skippedIndices.add(pIdx + i);
        }
      }
    }
    
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
      itemCount: _draft.periods.length,
      itemBuilder: (context, index) {
        if (skippedIndices.contains(index)) return const SizedBox.shrink();

        final period = _draft.periods[index];
        final periodLectures = daySlots[period.id] ?? [];
        
        int maxDuration = 1;
        for (final slot in periodLectures) {
          if (slot.durationPeriods > maxDuration) {
            maxDuration = slot.durationPeriods;
          }
        }
        
        String timeStr = '${_formatTime(period.startMinutes)} - ${_formatTime(period.endMinutes)}';
        if (maxDuration > 1) {
          final lastIdx = (index + maxDuration - 1).clamp(0, _draft.periods.length - 1);
          timeStr = '${_formatTime(period.startMinutes)} - ${_formatTime(_draft.periods[lastIdx].endMinutes)}';
        }
        
        if (period.isBreak) {
          // If it's a break slot and has custom break assignment
          if (periodLectures.isNotEmpty && periodLectures.first.isNonLecture) {
            final slot = periodLectures.first;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => _openPeriodConfig(day, period.id),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: sem.borderSubtle),
                    color: sem.surfaceElevated,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.event_available_rounded, color: sem.onSurfaceMuted, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text('${slot.type.name.toUpperCase()} • $timeStr', 
                            style: GoogleFonts.inter(fontSize: 13, color: sem.onSurfaceMuted, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(child: Divider(color: sem.borderSubtle)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('${period.name} • $timeStr', 
                      style: GoogleFonts.inter(fontSize: 12, color: sem.onSurfaceMuted, fontWeight: FontWeight.w600)),
                ),
                Expanded(child: Divider(color: sem.borderSubtle)),
              ],
            ),
          );
        }

        if (periodLectures.isEmpty) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: sem.borderSubtle),
              color: isDark ? sem.surfaceElevated : cs.surface,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: InkWell(
              onTap: () => _openPeriodConfig(day, period.id),
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                          child: Text(period.name, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: cs.primary)),
                        ),
                        const SizedBox(width: 8),
                        Text(timeStr, style: GoogleFonts.inter(fontSize: 12, color: sem.onSurfaceMuted, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_rounded, color: cs.primary, size: 20),
                          const SizedBox(width: 8),
                          Text('Configure Period', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: cs.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: sem.borderSubtle),
            color: isDark ? sem.surfaceElevated : cs.surface,
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Period Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                      child: Text(period.name, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: cs.primary)),
                    ),
                    const SizedBox(width: 8),
                    Text(timeStr, style: GoogleFonts.inter(fontSize: 12, color: sem.onSurfaceMuted, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              
              ...periodLectures.asMap().entries.map((entry) {
                final idx = entry.key;
                final slot = entry.value;
                final isWholeClass = slot.batch == 'Whole Class';

                return Column(
                  children: [
                    if (idx > 0) Divider(color: sem.borderSubtle, height: 1, indent: 16, endIndent: 16),
                    
                    InkWell(
                      onTap: () => _openPeriodConfig(day, period.id),
                      onLongPress: () => _showSlotOptions(day, period.id, slot, idx),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            if (!isWholeClass)
                              SizedBox(
                                width: 70,
                                child: Text(slot.batch ?? 'Batch', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: cs.onSurface)),
                              ),
                            if (!isWholeClass) const SizedBox(width: 12),
                            Expanded(
                              child: slot.isFilled
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(slot.subject ?? '', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          if (slot.room != null && slot.room!.isNotEmpty)
                                            _buildChip(Icons.door_front_door_outlined, slot.room!, sem),
                                          _buildChip(Icons.category_outlined, slot.component, sem),
                                          if (slot.durationPeriods > 1)
                                            _buildChip(Icons.access_time_rounded, '${slot.durationPeriods} Periods', sem),
                                        ],
                                      ),
                                    ],
                                  )
                                : Align(
                                    alignment: Alignment.centerLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                                      child: Text('+ Add Lecture', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: cs.primary)),
                                    ),
                                  ),
                            ),
                            const SizedBox(width: 8),
                            Icon(Icons.more_vert_rounded, size: 18, color: sem.onSurfaceMuted.withValues(alpha: 0.5)),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        );
      },
    );
  }

  Widget _buildChip(IconData icon, String label, AppSemanticColors sem) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: sem.surfaceElevated,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: sem.borderSubtle),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: sem.onSurfaceMuted),
          const SizedBox(width: 4),
          Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: sem.onSurfaceMuted)),
        ],
      ),
    );
  }
}
