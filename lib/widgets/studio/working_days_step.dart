import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/theme.dart';
import 'bottom_continue_button.dart';

class WorkingDaysStep extends StatefulWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final VoidCallback onContinue;

  const WorkingDaysStep({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.onContinue,
  });

  @override
  State<WorkingDaysStep> createState() => _WorkingDaysStepState();
}

class _WorkingDaysStepState extends State<WorkingDaysStep> {
  static const _allDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];
  late List<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List.from(widget.selected);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Which days does your college operate?',
                  style: GoogleFonts.outfit(
                      fontSize: 26, fontWeight: FontWeight.w700, height: 1.2),
                ),
                const SizedBox(height: 10),
                Text(
                  'Select all the days your class has lectures.',
                  style: GoogleFonts.inter(
                      fontSize: 16, color: sem.onSurfaceMuted, height: 1.5),
                ),
                const SizedBox(height: 40),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _allDays.map((day) {
                    final isSelected = _selected.contains(day);
                    return _AnimatedDayChip(
                      label: day,
                      selected: isSelected,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          if (isSelected) {
                            if (_selected.length > 1) _selected.remove(day);
                          } else {
                            _selected.add(day);
                            _selected.sort((a, b) => _allDays
                                .indexOf(a)
                                .compareTo(_allDays.indexOf(b)));
                          }
                        });
                        widget.onChanged(_selected);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                AnimatedSize(
                  duration: const Duration(milliseconds: 250),
                  child: _selected.isEmpty
                      ? Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.errorContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.warning_rounded,
                                  size: 16, color: cs.error),
                              const SizedBox(width: 8),
                              Text('Select at least one day',
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      color: cs.error,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        BottomContinueButton(
          enabled: _selected.isNotEmpty,
          onTap: widget.onContinue,
          label: 'Continue',
        ),
      ],
    );
  }
}

class _AnimatedDayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _AnimatedDayChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: selected ? cs.primary : sem.surfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? cs.primary : sem.borderSubtle,
            width: selected ? 2 : 1.5,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                      color: cs.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4))
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_circle_rounded,
                  size: 16, color: Colors.white),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : cs.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
