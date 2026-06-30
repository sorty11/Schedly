import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_settings.dart';
import 'models/timetable_entry.dart';
import 'models/event_category.dart';
import 'timetable_manager.dart';
import 'theme/theme.dart';
import 'widgets/animations/animated_card.dart';

// ─── NMIMS hardcoded periods ────────────────────────────────────────────────
class _NMIMSPeriod {
  final String name;
  final int startTime; // minutes from midnight
  final int endTime;
  final bool isBreak;

  const _NMIMSPeriod({
    required this.name,
    required this.startTime,
    required this.endTime,
    this.isBreak = false,
  });
}

const _kWorkingDays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
];

const _kPeriods = [
  _NMIMSPeriod(name: 'Period 1', startTime: 9 * 60 + 15, endTime: 10 * 60 + 15),
  _NMIMSPeriod(name: 'Period 2', startTime: 10 * 60 + 15, endTime: 11 * 60 + 15),
  _NMIMSPeriod(name: 'Break',    startTime: 11 * 60 + 15, endTime: 11 * 60 + 30, isBreak: true),
  _NMIMSPeriod(name: 'Period 3', startTime: 11 * 60 + 30, endTime: 12 * 60 + 30),
  _NMIMSPeriod(name: 'Period 4', startTime: 12 * 60 + 30, endTime: 13 * 60 + 30),
  _NMIMSPeriod(name: 'Period 5', startTime: 13 * 60 + 30, endTime: 14 * 60 + 30),
  _NMIMSPeriod(name: 'Period 6', startTime: 14 * 60 + 30, endTime: 15 * 60 + 30),
];

// Periods that need a lecture (non-break)
const _kAcademicPeriods = 6;

// ─── Entry Point ─────────────────────────────────────────────────────────────
class ManualTimetableBuilderPage extends StatefulWidget {
  final String division;

  const ManualTimetableBuilderPage({super.key, required this.division});

  @override
  State<ManualTimetableBuilderPage> createState() => _ManualTimetableBuilderPageState();
}

class _ManualTimetableBuilderPageState extends State<ManualTimetableBuilderPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _publishing = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _kWorkingDays.length, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatTime(int mins) {
    final h = (mins ~/ 60).toString().padLeft(2, '0');
    final m = (mins % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  // ─── Firestore stream per day ───────────────────────────────────────────────
  Stream<QuerySnapshot> _dayStream(String day) {
    return FirebaseFirestore.instance
        .collection('timetables')
        .doc(widget.division)
        .collection(day)
        .snapshots();
  }

  // ─── Day completion state ───────────────────────────────────────────────────
  // We fetch this once as a Future per day for the progress strip.
  Future<int> _lectureCountForDay(String day) async {
    final snap = await FirebaseFirestore.instance
        .collection('timetables')
        .doc(widget.division)
        .collection(day)
        .where('isActive', isEqualTo: true)
        .get();
    return snap.docs.length;
  }

  // ─── Publish ────────────────────────────────────────────────────────────────
  Future<void> _publish() async {
    setState(() => _publishing = true);
    try {
      // Validate all days have at least some lectures
      final errors = <String>[];
      for (final day in _kWorkingDays) {
        final count = await _lectureCountForDay(day);
        if (count == 0) errors.add(day);
      }

      if (errors.isNotEmpty && mounted) {
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Missing Lectures'),
            content: Text(
              'The following days have no lectures:\n${errors.join(", ")}\n\nPublish anyway?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Publish')),
            ],
          ),
        );
        if (proceed != true) {
          setState(() => _publishing = false);
          return;
        }
      }

      // Mark section as having a timetable published
      await FirebaseFirestore.instance
          .collection('sections')
          .doc(widget.division)
          .set({'timetablePublished': true}, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Timetable published successfully!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context); // Return to dashboard
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Publish failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _publishing = false);
    }
  }

  // ─── Open lecture sheet for a specific period ────────────────────────────
  Future<void> _openSheet({
    required BuildContext context,
    required String day,
    required _NMIMSPeriod period,
    TimetableEntry? existing,
    _NMIMSPeriod? nextPeriod,
  }) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddLectureSheet(
        division: widget.division,
        day: day,
        period: period,
        existing: existing,
        onSaveAndNext: nextPeriod != null
            ? () {
                // After this sheet closes, open next period's sheet
                Future.microtask(() {
                  if (context.mounted) {
                    _openSheet(
                      context: context,
                      day: day,
                      period: nextPeriod,
                    );
                  }
                });
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Timetable Builder',
              style: GoogleFonts.outfit(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            Text(
              AppSettings.sectionId ?? widget.division,
              style: GoogleFonts.inter(fontSize: 12, color: sem.onSurfaceMuted),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: _publishing ? null : _publish,
            icon: _publishing
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.publish_rounded, size: 18),
            label: const Text('Publish'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(width: 12),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              // ── Day progress strip ──────────────────────────────────────
              _DayProgressStrip(division: widget.division, tabController: _tabController),
              // ── Tab bar ─────────────────────────────────────────────────
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: _kWorkingDays
                    .map((day) => Tab(text: day.substring(0, 3)))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _kWorkingDays.map((day) {
          return _DayBuilderView(
            division: widget.division,
            day: day,
            dayStream: _dayStream(day),
            onOpenSheet: (period, existing, nextPeriod) => _openSheet(
              context: context,
              day: day,
              period: period,
              existing: existing,
              nextPeriod: nextPeriod,
            ),
            onContinueToNextDay: _kWorkingDays.indexOf(day) < _kWorkingDays.length - 1
                ? () => _tabController.animateTo(_kWorkingDays.indexOf(day) + 1)
                : null,
          );
        }).toList(),
      ),
    );
  }
}

// ─── Day Progress Strip ───────────────────────────────────────────────────────
class _DayProgressStrip extends StatelessWidget {
  final String division;
  final TabController tabController;

  const _DayProgressStrip({required this.division, required this.tabController});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        itemCount: _kWorkingDays.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final day = _kWorkingDays[i];
          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('timetables')
                .doc(division)
                .collection(day)
                .where('isActive', isEqualTo: true)
                .get(),
            builder: (context, snap) {
              final count = snap.data?.docs.length ?? 0;
              final isDone = count >= _kAcademicPeriods;
              final isCurrent = tabController.index == i;

              return GestureDetector(
                onTap: () => tabController.animateTo(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDone
                        ? Colors.green.withValues(alpha: 0.15)
                        : isCurrent
                            ? colorScheme.primary.withValues(alpha: 0.12)
                            : sem.borderSubtle.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDone
                          ? Colors.green
                          : isCurrent
                              ? colorScheme.primary
                              : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isDone) ...[
                        const Icon(Icons.check_circle_rounded, size: 14, color: Colors.green),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        day.substring(0, 3),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDone
                              ? Colors.green
                              : isCurrent
                                  ? colorScheme.primary
                                  : sem.onSurfaceMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// ─── Day Builder View ─────────────────────────────────────────────────────────
class _DayBuilderView extends StatelessWidget {
  final String division;
  final String day;
  final Stream<QuerySnapshot> dayStream;
  final Future<void> Function(_NMIMSPeriod, TimetableEntry?, _NMIMSPeriod?) onOpenSheet;
  final VoidCallback? onContinueToNextDay;

  const _DayBuilderView({
    required this.division,
    required this.day,
    required this.dayStream,
    required this.onOpenSheet,
    required this.onContinueToNextDay,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: dayStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];
        final entries = docs.map((d) => TimetableEntry.fromFirestore(d)).toList();

        // Count filled academic periods
        int filledCount = 0;
        for (final period in _kPeriods) {
          if (!period.isBreak) {
            if (entries.any((e) => e.startTime == period.startTime && e.isActive)) {
              filledCount++;
            }
          }
        }
        final isDayComplete = filledCount >= _kAcademicPeriods;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            // ── Period cards ────────────────────────────────────────────
            ..._kPeriods.asMap().entries.map((entry) {
              final idx = entry.key;
              final period = entry.value;
              final periodEntries = entries
                  .where((e) => e.startTime == period.startTime)
                  .toList();

              // Find next academic period
              _NMIMSPeriod? nextAcademic;
              for (int j = idx + 1; j < _kPeriods.length; j++) {
                if (!_kPeriods[j].isBreak) {
                  nextAcademic = _kPeriods[j];
                  break;
                }
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _PeriodCard(
                  division: division,
                  day: day,
                  period: period,
                  entries: periodEntries,
                  nextPeriod: nextAcademic,
                  onOpenSheet: onOpenSheet,
                ),
              );
            }),

            // ── Day complete card ───────────────────────────────────────
            if (isDayComplete) ...[
              const SizedBox(height: 8),
              _DayCompleteCard(
                day: day,
                onContinue: onContinueToNextDay,
              ),
              const SizedBox(height: 16),
            ],
          ],
        );
      },
    );
  }
}

// ─── Period Card ──────────────────────────────────────────────────────────────
class _PeriodCard extends StatelessWidget {
  final String division;
  final String day;
  final _NMIMSPeriod period;
  final List<TimetableEntry> entries;
  final _NMIMSPeriod? nextPeriod;
  final Future<void> Function(_NMIMSPeriod, TimetableEntry?, _NMIMSPeriod?) onOpenSheet;

  const _PeriodCard({
    required this.division,
    required this.day,
    required this.period,
    required this.entries,
    required this.nextPeriod,
    required this.onOpenSheet,
  });

  String _fmt(int mins) {
    final h = (mins ~/ 60).toString().padLeft(2, '0');
    final m = (mins % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _deletEntry(BuildContext context, TimetableEntry entry) {
    FirebaseFirestore.instance
        .collection('timetables')
        .doc(division)
        .collection(day)
        .doc(entry.id)
        .delete();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    // Break row
    if (period.isBreak) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: sem.borderSubtle.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.coffee_rounded, size: 15, color: sem.onSurfaceMuted),
            const SizedBox(width: 8),
            Text(
              '${period.name}  •  ${_fmt(period.startTime)} – ${_fmt(period.endTime)}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: sem.onSurfaceMuted,
              ),
            ),
          ],
        ),
      );
    }

    // Empty period
    if (entries.isEmpty) {
      return AnimatedCard(
        onTap: () => onOpenSheet(period, null, nextPeriod),
        backgroundColor: colorScheme.surface,
        borderRadius: AppRadius.lg,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: sem.borderSubtle, width: 1.2),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _PeriodBadge(label: period.name, color: colorScheme.primary.withValues(alpha: 0.8)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '+ Add Lecture',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_fmt(period.startTime)} – ${_fmt(period.endTime)}',
                      style: GoogleFonts.inter(fontSize: 12, color: sem.onSurfaceMuted),
                    ),
                  ],
                ),
              ),
              Icon(Icons.add_circle_outline_rounded, color: colorScheme.primary, size: 22),
            ],
          ),
        ),
      );
    }

    // Filled period(s)
    return Column(
      children: entries.map((entry) {
        return AnimatedCard(
          onTap: () => onOpenSheet(period, entry, nextPeriod),
          backgroundColor: colorScheme.surface,
          borderRadius: AppRadius.lg,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border(
                left: BorderSide(color: colorScheme.primary, width: 4),
                top: BorderSide(color: sem.borderSubtle, width: 0.8),
                right: BorderSide(color: sem.borderSubtle, width: 0.8),
                bottom: BorderSide(color: sem.borderSubtle, width: 0.8),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _PeriodBadge(label: period.name, color: colorScheme.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.displaySubject,
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        children: [
                          _InfoChip(icon: Icons.schedule_rounded, label: '${_fmt(period.startTime)} – ${_fmt(period.endTime)}', sem: sem),
                          if (entry.room != null && entry.room!.isNotEmpty)
                            _InfoChip(icon: Icons.room_rounded, label: entry.room!, sem: sem),
                          if (entry.batch != 'Whole Class')
                            _InfoChip(icon: Icons.groups_rounded, label: entry.batch, sem: sem),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, color: colorScheme.error.withValues(alpha: 0.7), size: 20),
                  onPressed: () => _deletEntry(context, entry),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Period Badge ──────────────────────────────────────────────────────────────
class _PeriodBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _PeriodBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Text(
          label.replaceAll('Period ', 'P'),
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }
}

// ─── Info Chip ─────────────────────────────────────────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppSemanticColors sem;

  const _InfoChip({required this.icon, required this.label, required this.sem});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: sem.onSurfaceMuted),
        const SizedBox(width: 3),
        Text(label, style: GoogleFonts.inter(fontSize: 12, color: sem.onSurfaceMuted)),
      ],
    );
  }
}

// ─── Day Complete Card ─────────────────────────────────────────────────────────
class _DayCompleteCard extends StatelessWidget {
  final String day;
  final VoidCallback? onContinue;

  const _DayCompleteCard({required this.day, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle_rounded, color: Colors.green, size: 40),
          const SizedBox(height: 12),
          Text(
            '✓ $day Complete',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Colors.green[700],
            ),
          ),
          if (onContinue != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Continue to Next Day'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Add Lecture Sheet ────────────────────────────────────────────────────────
class _AddLectureSheet extends StatefulWidget {
  final String division;
  final String day;
  final _NMIMSPeriod period;
  final TimetableEntry? existing;
  final VoidCallback? onSaveAndNext;

  const _AddLectureSheet({
    required this.division,
    required this.day,
    required this.period,
    this.existing,
    this.onSaveAndNext,
  });

  @override
  State<_AddLectureSheet> createState() => _AddLectureSheetState();
}

class _AddLectureSheetState extends State<_AddLectureSheet> {
  // ── Static memory so suggestions persist ──────────────────────────────────
  static List<String> _cachedSubjects = [];
  static List<String> _cachedRooms = [];

  late TextEditingController _subjectCtrl;
  late TextEditingController _roomCtrl;
  late String _batch;
  late String _component;
  late EventCategory _category;
  bool _saving = false;

  final List<String> _batchOptions = ['Whole Class', 'Batch 1', 'Batch 2', 'Batch 3'];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _subjectCtrl = TextEditingController(text: e?.subject ?? '');
    _roomCtrl = TextEditingController(text: e?.room ?? '');
    _batch = e?.batch ?? _batchOptions.first;
    _component = e?.component ?? 'Theory';
    _category = e?.category ?? EventCategory.academic;
    _fetchSuggestions();
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSuggestions() async {
    if (_cachedSubjects.isNotEmpty) return; // already cached
    final subjects = await TimetableManager.getUniqueSubjects(division: widget.division);
    final Set<String> rooms = {};
    for (final day in _kWorkingDays) {
      final entries = await TimetableManager.getEntriesForDay(
          division: widget.division, day: day);
      for (final e in entries) {
        if (e.room != null && e.room!.trim().isNotEmpty) {
          rooms.add(e.room!.trim());
        }
      }
    }
    if (mounted) {
      setState(() {
        _cachedSubjects = subjects;
        _cachedRooms = rooms.toList()..sort();
      });
    }
  }

  Future<void> _save({required bool andNext}) async {
    final subject = _subjectCtrl.text.trim();
    final room = _roomCtrl.text.trim();

    if (subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Subject cannot be empty'), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (room.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room / Lab cannot be empty'), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    // Duplicate check (only on new entries)
    if (widget.existing == null) {
      final overlap = await FirebaseFirestore.instance
          .collection('timetables')
          .doc(widget.division)
          .collection(widget.day)
          .where('startTime', isEqualTo: widget.period.startTime)
          .where('batch', isEqualTo: _batch)
          .where('isActive', isEqualTo: true)
          .get();
      if (overlap.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$_batch already has a lecture at ${widget.period.name}'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final entry = TimetableEntry(
        id: widget.existing?.id ?? FirebaseFirestore.instance.collection('timetables').doc().id,
        subject: subject,
        component: _component,
        category: _category,
        batch: _batch,
        startTime: widget.period.startTime,
        endTime: widget.period.endTime,
        durationMinutes: widget.period.endTime - widget.period.startTime,
        room: room,
        isActive: true,
      );

      if (widget.existing != null) {
        // Edit: write directly (same ID, same slot) - no duplicate check needed
        await FirebaseFirestore.instance
            .collection('timetables')
            .doc(widget.division)
            .collection(widget.day)
            .doc(widget.existing!.id)
            .set(entry.toFirestore());
      } else {
        // New lecture: use TimetableManager for duplicate enforcement
        await TimetableManager.addLecture(
          division: widget.division,
          day: widget.day,
          entry: entry,
        );
      }

      // Update cache
      if (!_cachedSubjects.contains(subject)) _cachedSubjects.add(subject);
      if (room.isNotEmpty && !_cachedRooms.contains(room)) _cachedRooms.add(room);

      if (!mounted) return;
      Navigator.pop(context);
      if (andNext) widget.onSaveAndNext?.call();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String fmtTime(int m) {
      final h = (m ~/ 60).toString().padLeft(2, '0');
      final min = (m % 60).toString().padLeft(2, '0');
      return '$h:$min';
    }

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? sem.surfaceElevated : colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: sem.onSurfaceMuted.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      widget.period.name,
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${fmtTime(widget.period.startTime)} – ${fmtTime(widget.period.endTime)}',
                    style: GoogleFonts.inter(fontSize: 13, color: sem.onSurfaceMuted),
                  ),
                  const Spacer(),
                  Text(
                    widget.day,
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w600, color: sem.onSurfaceMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                widget.existing != null ? 'Edit Lecture' : 'Add Lecture',
                style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),

              // Subject
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _subjectCtrl.text),
                optionsBuilder: (tv) {
                  if (tv.text.isEmpty) return _cachedSubjects;
                  return _cachedSubjects.where(
                    (s) => s.toLowerCase().contains(tv.text.toLowerCase()),
                  );
                },
                onSelected: (v) => _subjectCtrl.text = v,
                fieldViewBuilder: (ctx, ctrl, fn, _) {
                  // Sync our controller
                  ctrl.text = _subjectCtrl.text;
                  ctrl.addListener(() => _subjectCtrl.text = ctrl.text);
                  return TextFormField(
                    controller: ctrl,
                    focusNode: fn,
                    autofocus: widget.existing == null,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Subject *',
                      prefixIcon: const Icon(Icons.book_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // Room
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _roomCtrl.text),
                optionsBuilder: (tv) {
                  if (tv.text.isEmpty) return _cachedRooms;
                  return _cachedRooms.where(
                    (r) => r.toLowerCase().contains(tv.text.toLowerCase()),
                  );
                },
                onSelected: (v) => _roomCtrl.text = v,
                fieldViewBuilder: (ctx, ctrl, fn, _) {
                  ctrl.text = _roomCtrl.text;
                  ctrl.addListener(() => _roomCtrl.text = ctrl.text);
                  return TextFormField(
                    controller: ctrl,
                    focusNode: fn,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Room / Lab *',
                      prefixIcon: const Icon(Icons.room_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                    ),
                  );
                },
              ),
              const SizedBox(height: 14),

              // Batch
              DropdownButtonFormField<String>(
                value: _batch,
                decoration: InputDecoration(
                  labelText: 'Batch',
                  prefixIcon: const Icon(Icons.groups_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                ),
                items: _batchOptions
                    .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                    .toList(),
                onChanged: (v) => setState(() => _batch = v!),
              ),
              const SizedBox(height: 14),

              // Lecture type chips
              Text('Lecture Type', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: sem.onSurfaceMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _typeChip('Theory', 'Theory', EventCategory.academic, colorScheme),
                  _typeChip('Lab', 'Lab', EventCategory.academic, colorScheme),
                  _typeChip('Tutorial', 'Tutorial', EventCategory.academic, colorScheme),
                  _typeChip('Event', 'Event', EventCategory.event, colorScheme),
                ],
              ),
              const SizedBox(height: 28),

              // Action buttons
              Row(
                children: [
                  if (widget.onSaveAndNext != null)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving ? null : () => _save(andNext: true),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _saving
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Text('Save & Next', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                  if (widget.onSaveAndNext != null) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : () => _save(andNext: false),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _typeChip(String label, String component, EventCategory cat, ColorScheme cs) {
    final isSelected = _component == component && _category == cat;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (v) {
        if (v) setState(() { _component = component; _category = cat; });
      },
    );
  }
}
