import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/studio_state.dart';
import '../../theme/theme.dart';
import '../app_dialogs.dart';

class PeriodConfigSheet extends StatefulWidget {
  final PeriodDef period;
  final List<SlotState> initialSlots;
  final ValueChanged<List<SlotState>> onSave;

  const PeriodConfigSheet({
    super.key,
    required this.period,
    required this.initialSlots,
    required this.onSave,
  });

  @override
  State<PeriodConfigSheet> createState() => _PeriodConfigSheetState();
}

class _PeriodConfigSheetState extends State<PeriodConfigSheet> {
  bool _isSplit = false;
  int _duration = 1;
  int _splitCount = 2;

  // For Whole Class
  final _wcSubjectCtrl = TextEditingController();
  final _wcRoomCtrl = TextEditingController();
  String _wcComponent = 'Theory';
  SlotType _wcType = SlotType.lecture;

  // For Split
  final List<TextEditingController> _splitSubjCtrls = [];
  final List<TextEditingController> _splitRoomCtrls = [];
  final List<String> _splitComponents = [];
  final List<String> _splitBatches = [];

  @override
  void initState() {
    super.initState();
    _initFromState();
  }

  void _initFromState() {
    final slots = widget.initialSlots;
    if (slots.isEmpty) {
      _isSplit = false;
      _duration = 1;
    } else if (slots.length == 1 && slots.first.batch == 'Whole Class') {
      _isSplit = false;
      final s = slots.first;
      _wcSubjectCtrl.text = s.subject ?? '';
      _wcRoomCtrl.text = s.room ?? '';
      _wcComponent = s.component;
      _wcType = s.type;
      _duration = s.durationPeriods;
    } else {
      _isSplit = true;
      _duration = slots.first.durationPeriods; // Merged periods apply to the whole slot
      _splitCount = slots.length;
      for (int i = 0; i < slots.length; i++) {
        _splitSubjCtrls.add(TextEditingController(text: slots[i].subject ?? ''));
        _splitRoomCtrls.add(TextEditingController(text: slots[i].room ?? ''));
        _splitComponents.add(slots[i].component);
        _splitBatches.add(slots[i].batch ?? 'A${i + 1}');
      }
    }
    
    // Ensure we have enough controllers if split
    _ensureSplitControllers(_splitCount);
  }

  void _ensureSplitControllers(int count) {
    while (_splitSubjCtrls.length < count) {
      _splitSubjCtrls.add(TextEditingController());
      _splitRoomCtrls.add(TextEditingController());
      _splitComponents.add('Theory');
      _splitBatches.add('A${_splitSubjCtrls.length}');
    }
  }

  @override
  void dispose() {
    _wcSubjectCtrl.dispose();
    _wcRoomCtrl.dispose();
    for (var c in _splitSubjCtrls) c.dispose();
    for (var c in _splitRoomCtrls) c.dispose();
    super.dispose();
  }

  void _save() {
    if (!_isSplit && _wcType == SlotType.lecture && _wcSubjectCtrl.text.trim().isEmpty) {
      AppDialogs.showSnackBar(
        context: context,
        message: 'Subject is required',
        isError: true,
      );
      return;
    }
    
    List<SlotState> res = [];
    if (!_isSplit) {
      res.add(SlotState(
        periodId: widget.period.id,
        type: _wcType,
        subject: _wcType == SlotType.lecture ? _wcSubjectCtrl.text.trim() : null,
        room: _wcType == SlotType.lecture ? _wcRoomCtrl.text.trim() : null,
        component: _wcComponent,
        batch: 'Whole Class',
        durationPeriods: _duration,
      ));
    } else {
      for (int i = 0; i < _splitCount; i++) {
        final subj = _splitSubjCtrls[i].text.trim();
        // Even if empty, we save the empty slot to maintain the lane
        res.add(SlotState(
          periodId: widget.period.id,
          type: SlotType.lecture,
          subject: subj.isEmpty ? null : subj,
          room: _splitRoomCtrls[i].text.trim().isEmpty ? null : _splitRoomCtrls[i].text.trim(),
          component: _splitComponents[i],
          batch: _splitBatches[i],
          durationPeriods: _duration,
        ));
      }
    }
    widget.onSave(res);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: isDark ? sem.surfaceElevated2 : cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        left: 24,
        right: 24,
        top: 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(color: sem.borderSubtle, borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.period.name, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700)),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
                style: IconButton.styleFrom(backgroundColor: sem.surfaceElevated),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('How is this lecture conducted?', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<bool>(
                          value: false,
                          groupValue: _isSplit,
                          onChanged: (v) => setState(() => _isSplit = v!),
                          title: Text('Whole Class', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<bool>(
                          value: true,
                          groupValue: _isSplit,
                          onChanged: (v) => setState(() => _isSplit = v!),
                          title: Text('Split into Batches', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600)),
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 32),

                  if (!_isSplit) _buildWholeClassForm(cs, sem) else _buildSplitForm(cs, sem),
                ],
              ),
            ),
          ),

          // Actions
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text('Save Period', style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWholeClassForm(ColorScheme cs, AppSemanticColors sem) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Slot Type
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildTypeChip('Lecture', SlotType.lecture, Icons.menu_book_rounded, cs, sem),
              _buildTypeChip('Free', SlotType.free, Icons.event_available_rounded, cs, sem),
              _buildTypeChip('Break', SlotType.breakSlot, Icons.coffee_rounded, cs, sem),
              _buildTypeChip('Lunch', SlotType.lunchSlot, Icons.restaurant_rounded, cs, sem),
            ],
          ),
        ),
        const SizedBox(height: 24),

        if (_wcType == SlotType.lecture) ...[
          TextFormField(
            controller: _wcSubjectCtrl,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Subject Name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.class_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _wcRoomCtrl,
            style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'Room / Lab',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.door_front_door_outlined),
            ),
          ),
          const SizedBox(height: 16),
          Text('Lecture Type', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: sem.onSurfaceMuted)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['Theory', 'Lab', 'Tutorial', 'Event'].map((c) {
              return ChoiceChip(
                label: Text(c, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                selected: _wcComponent == c,
                onSelected: (v) {
                  if (v) setState(() => _wcComponent = c);
                },
                backgroundColor: sem.surfaceElevated,
                selectedColor: cs.secondaryContainer,
              );
            }).toList(),
          ),
        ],

        const SizedBox(height: 24),
        Text('Duration (Periods)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: sem.onSurfaceMuted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [1, 2, 3].map((d) {
            return ChoiceChip(
              label: Text('$d Period${d > 1 ? 's' : ''}', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              selected: _duration == d,
              onSelected: (v) {
                if (v) setState(() => _duration = d);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildSplitForm(ColorScheme cs, AppSemanticColors sem) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Number of Batches', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: sem.onSurfaceMuted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [2, 3, 4].map((c) {
            return ChoiceChip(
              label: Text('$c Batches', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              selected: _splitCount == c,
              onSelected: (v) {
                if (v) {
                  setState(() {
                    _splitCount = c;
                    _ensureSplitControllers(c);
                  });
                }
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        Text('Duration (Periods)', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: sem.onSurfaceMuted)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [1, 2, 3].map((d) {
            return ChoiceChip(
              label: Text('$d Period${d > 1 ? 's' : ''}', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              selected: _duration == d,
              onSelected: (v) {
                if (v) setState(() => _duration = d);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        for (int i = 0; i < _splitCount; i++) ...[
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: sem.surfaceElevated,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: sem.borderSubtle),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: cs.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_splitBatches[i], style: GoogleFonts.outfit(fontWeight: FontWeight.w700, color: cs.onPrimaryContainer)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _splitSubjCtrls[i],
                  decoration: const InputDecoration(labelText: 'Subject', isDense: true),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _splitRoomCtrls[i],
                        decoration: const InputDecoration(labelText: 'Room', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _splitComponents[i],
                        decoration: const InputDecoration(labelText: 'Type', isDense: true),
                        items: ['Theory', 'Lab', 'Tutorial', 'Event'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _splitComponents[i] = v);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTypeChip(String label, SlotType type, IconData icon, ColorScheme cs, AppSemanticColors sem) {
    final selected = _wcType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
        avatar: Icon(icon, size: 16),
        selected: selected,
        onSelected: (v) {
          if (v) setState(() => _wcType = type);
        },
      ),
    );
  }
}
