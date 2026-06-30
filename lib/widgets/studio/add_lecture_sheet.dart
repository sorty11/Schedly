import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/studio_state.dart';
import '../../theme/theme.dart';

class AddLectureSheet extends StatefulWidget {
  final SlotState slot;
  final String periodName;
  final String timeString;
  final ValueChanged<SlotState> onSave;
  final ValueChanged<SlotState>? onSaveAndNext;
  final VoidCallback? onDelete;

  const AddLectureSheet({
    super.key,
    required this.slot,
    required this.periodName,
    required this.timeString,
    required this.onSave,
    this.onSaveAndNext,
    this.onDelete,
  });

  @override
  State<AddLectureSheet> createState() => _AddLectureSheetState();
}

class _AddLectureSheetState extends State<AddLectureSheet> {
  late SlotType _type;
  late String _component;
  late String _batch;

  final _subjectCtrl = TextEditingController();
  final _roomCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _type = widget.slot.type;
    _component = widget.slot.component;
    _batch = widget.slot.batch ?? 'Whole Class';
    _subjectCtrl.text = widget.slot.subject ?? '';
    _roomCtrl.text = widget.slot.room ?? '';
  }

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  SlotState _buildState() {
    return widget.slot.copyWith(
      type: _type,
      component: _component,
      batch: _batch,
      subject: _type == SlotType.lecture ? _subjectCtrl.text.trim() : null,
      room: _type == SlotType.lecture ? _roomCtrl.text.trim() : null,
    );
  }

  void _save() {
    if (_type == SlotType.lecture && _subjectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subject is required')));
      return;
    }
    widget.onSave(_buildState());
    Navigator.pop(context);
  }

  void _saveAndNext() {
    if (_type == SlotType.lecture && _subjectCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Subject is required')));
      return;
    }
    if (widget.onSaveAndNext != null) {
      widget.onSaveAndNext!(_buildState());
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final isLecture = _type == SlotType.lecture;

    return Container(
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: sem.borderSubtle,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.periodName, style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.w700)),
                    Text(widget.timeString, style: GoogleFonts.inter(fontSize: 14, color: sem.onSurfaceMuted)),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(backgroundColor: sem.surfaceElevated),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Slot Type
            Text('Slot Type', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: sem.onSurfaceMuted)),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTypeChip('Lecture', SlotType.lecture, Icons.menu_book_rounded, cs, sem),
                  _buildTypeChip('Free', SlotType.free, Icons.event_available_rounded, cs, sem),
                  _buildTypeChip('Break', SlotType.breakSlot, Icons.coffee_rounded, cs, sem),
                  _buildTypeChip('Lunch', SlotType.lunchSlot, Icons.restaurant_rounded, cs, sem),
                  _buildTypeChip('Holiday', SlotType.holiday, Icons.celebration_rounded, cs, sem),
                ],
              ),
            ),
            const SizedBox(height: 24),

            if (isLecture) ...[
              // Subject
              TextFormField(
                controller: _subjectCtrl,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Subject Name',
                  hintText: 'e.g. Mathematics',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.class_outlined),
                ),
              ),
              const SizedBox(height: 20),

              // Room
              TextFormField(
                controller: _roomCtrl,
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16),
                decoration: InputDecoration(
                  labelText: 'Room / Lab',
                  hintText: 'e.g. Room 402',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.door_front_door_outlined),
                ),
              ),


              // Component Type
              Text('Lecture Type', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: sem.onSurfaceMuted)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: ['Theory', 'Lab', 'Tutorial', 'Event'].map((c) {
                  final selected = _component == c;
                  return ChoiceChip(
                    label: Text(c, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                    selected: selected,
                    onSelected: (v) {
                      if (v) setState(() => _component = c);
                    },
                    backgroundColor: sem.surfaceElevated,
                    selectedColor: cs.secondaryContainer,
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
            ] else ...[
              const SizedBox(height: 32),
            ],

            // Actions
            Row(
              children: [
                if (widget.onDelete != null) ...[
                  IconButton(
                    onPressed: () {
                      widget.onDelete!();
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.delete_outline_rounded, color: sem.cancelled),
                    style: IconButton.styleFrom(
                      backgroundColor: sem.cancelled.withValues(alpha: 0.1),
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: OutlinedButton(
                    onPressed: _save,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: sem.borderSubtle, width: 1.5),
                    ),
                    child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: cs.onSurface)),
                  ),
                ),
                if (widget.onSaveAndNext != null) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _saveAndNext,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text('Save & Next', style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(String label, SlotType type, IconData icon, ColorScheme cs, AppSemanticColors sem) {
    final selected = _type == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: selected ? cs.onPrimaryContainer : cs.onSurface)),
        avatar: Icon(icon, size: 16, color: selected ? cs.onPrimaryContainer : sem.onSurfaceMuted),
        selected: selected,
        onSelected: (v) {
          if (v) setState(() => _type = type);
        },
        backgroundColor: sem.surfaceElevated,
        selectedColor: cs.primaryContainer,
        showCheckmark: false,
      ),
    );
  }
}
