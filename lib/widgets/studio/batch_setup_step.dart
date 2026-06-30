import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/theme.dart';
import 'bottom_continue_button.dart';

class BatchOption {
  final IconData icon;
  final String title;
  final String subtitle;

  const BatchOption({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class BatchSetupStep extends StatefulWidget {
  final int option;
  final List<String> batches;
  final ValueChanged<int> onOptionChanged;
  final ValueChanged<List<String>> onBatchesChanged;
  final VoidCallback onContinue;

  const BatchSetupStep({
    super.key,
    required this.option,
    required this.batches,
    required this.onOptionChanged,
    required this.onBatchesChanged,
    required this.onContinue,
  });

  @override
  State<BatchSetupStep> createState() => _BatchSetupStepState();
}

class _BatchSetupStepState extends State<BatchSetupStep> {
  late int _option;
  late List<String> _batches;

  @override
  void initState() {
    super.initState();
    _option = widget.option;
    _batches = List.from(widget.batches);
    print('DEBUG BatchSetupStep [initState]: _option=$_option, _batches=$_batches, widget.batches=${widget.batches}');
  }

  @override
  void didUpdateWidget(BatchSetupStep oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('DEBUG BatchSetupStep [didUpdateWidget]: widget.batches=${widget.batches}, oldWidget.batches=${oldWidget.batches}, _batches=$_batches');
    // We intentionally don't overwrite _batches with widget.batches to preserve local edits
  }

  void _selectOption(int opt) {
    setState(() => _option = opt);
    widget.onOptionChanged(opt);
    
    if (opt == 0) {
      _batches = ['Whole Class'];
      print('DEBUG BatchSetupStep [_selectOption]: emitted [Whole Class]');
      widget.onBatchesChanged(_batches);
    } else if (opt == 1) {
      if (_batches.length != 2 || _batches.contains('Whole Class')) {
        _batches = ['A1', 'A2'];
        print('DEBUG BatchSetupStep [_selectOption]: emitted [A1, A2]');
        widget.onBatchesChanged(_batches);
      } else {
        print('DEBUG BatchSetupStep [_selectOption]: skipped emitting, _batches already $_batches');
      }
    } else if (opt == 2) {
      if (_batches.length != 3 || _batches.contains('Whole Class')) {
        _batches = ['A1', 'A2', 'A3'];
        print('DEBUG BatchSetupStep [_selectOption]: emitted [A1, A2, A3]');
        widget.onBatchesChanged(_batches);
      }
    } else if (opt == 3) {
      if (_batches.length != 4 || _batches.contains('Whole Class')) {
        _batches = ['A1', 'A2', 'A3', 'A4'];
        print('DEBUG BatchSetupStep [_selectOption]: emitted [A1, A2, A3, A4]');
        widget.onBatchesChanged(_batches);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('DEBUG BatchSetupStep [build]: _option=$_option, _batches=$_batches, widget.batches=${widget.batches}');
    final cs = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    final options = [
      const BatchOption(
          icon: Icons.groups_rounded,
          title: 'Whole Class Only',
          subtitle: 'No sub-groups'),
      const BatchOption(
          icon: Icons.group_rounded,
          title: '2 Batches',
          subtitle: 'e.g. Batch 1 & Batch 2'),
      const BatchOption(
          icon: Icons.diversity_3_rounded,
          title: '3 Batches',
          subtitle: 'e.g. Batch 1, 2 & 3'),
      const BatchOption(
          icon: Icons.grid_view_rounded,
          title: '4 Batches',
          subtitle: 'e.g. Batch 1, 2, 3 & 4'),
      const BatchOption(
          icon: Icons.tune_rounded,
          title: 'Custom',
          subtitle: 'Define your own groups'),
    ];

    // To prevent rapid rebuilding/losing focus on text fields, we use independent controllers,
    // but a simpler way is to just use TextFormField with initialValue and onChanged.
    // We will render them below the card if selected.

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DEBUG BATCHES IN SETUP: ${widget.batches}', style: TextStyle(color: Colors.red)),
                Text(
                  'How are students grouped?',
                  style: GoogleFonts.outfit(
                      fontSize: 26, fontWeight: FontWeight.w700, height: 1.2),
                ),
                const SizedBox(height: 10),
                Text(
                  'This determines lecture batch assignments.',
                  style: GoogleFonts.inter(
                      fontSize: 16, color: sem.onSurfaceMuted, height: 1.5),
                ),
                const SizedBox(height: 32),
                ...options.asMap().entries.map((e) {
                  final idx = e.key;
                  final opt = e.value;
                  final isSelected = _option == idx;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _selectOption(idx);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? cs.primary.withValues(alpha: 0.06)
                              : sem.surfaceElevated,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isSelected ? cs.primary : sem.borderSubtle,
                            width: isSelected ? 2 : 1.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                      color: cs.primary.withValues(alpha: 0.12),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4))
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? cs.primary.withValues(alpha: 0.12)
                                    : sem.borderSubtle.withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(opt.icon,
                                  size: 22,
                                  color: isSelected
                                      ? cs.primary
                                      : sem.onSurfaceMuted),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(opt.title,
                                      style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: isSelected
                                              ? cs.primary
                                              : cs.onSurface)),
                                  Text(opt.subtitle,
                                      style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: sem.onSurfaceMuted)),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Icon(Icons.check_circle_rounded,
                                  color: cs.primary, size: 22),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),

                // Batch Inputs for 2, 3, or 4 batches
                if (_option == 1 || _option == 2 || _option == 3) ...[
                  const SizedBox(height: 8),
                  Text('Batch Names',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: sem.onSurfaceMuted)),
                  const SizedBox(height: 12),
                  Row(
                    children: List.generate(_option == 1 ? 2 : (_option == 2 ? 3 : 4), (i) {
                      final currentName = i < _batches.length ? _batches[i] : 'A${i+1}';
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i < (_option == 1 ? 1 : (_option == 2 ? 2 : 3)) ? 8.0 : 0),
                          child: TextFormField(
                            key: ValueKey('batch_${_option}_$i'),
                            initialValue: currentName,
                            decoration: InputDecoration(
                              labelText: 'Batch ${i+1}',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: sem.surfaceElevated,
                            ),
                            onChanged: (val) {
                              final newBatches = List<String>.from(_batches);
                              if (i < newBatches.length) {
                                newBatches[i] = val.trim().isEmpty ? 'A${i+1}' : val.trim();
                              }
                              _batches = newBatches;
                              print('DEBUG BatchSetupStep [TextField onChanged]: $newBatches');
                              widget.onBatchesChanged(newBatches);
                            },
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 24),
                ],

                // Custom input
                if (_option == 4) ...[
                  const SizedBox(height: 8),
                  Text('Your Groups',
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: sem.onSurfaceMuted)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...widget.batches.map((batch) => Chip(
                            label: Text(batch, style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                            backgroundColor: sem.surfaceElevated,
                            side: BorderSide(color: sem.borderSubtle),
                            deleteIcon: const Icon(Icons.close, size: 16),
                            onDeleted: widget.batches.length > 1
                                ? () {
                                    final newBatches = List<String>.from(widget.batches)..remove(batch);
                                    widget.onBatchesChanged(newBatches);
                                  }
                                : null,
                          )),
                      ActionChip(
                        label: Text('Add Batch', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                        avatar: const Icon(Icons.add, size: 16),
                        backgroundColor: cs.primaryContainer.withValues(alpha: 0.5),
                        side: BorderSide(color: cs.primary.withValues(alpha: 0.3)),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) {
                              final ctrl = TextEditingController();
                              return AlertDialog(
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text('Add Batch', style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                                content: TextField(
                                  controller: ctrl,
                                  decoration: InputDecoration(
                                    hintText: 'e.g. Lab A',
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  autofocus: true,
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                  FilledButton(
                                    onPressed: () {
                                      if (ctrl.text.trim().isNotEmpty) {
                                        final newBatches = List<String>.from(widget.batches)..add(ctrl.text.trim());
                                        widget.onBatchesChanged(newBatches);
                                      }
                                      Navigator.pop(ctx);
                                    },
                                    child: const Text('Add'),
                                  ),
                                ],
                              );
                            }
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                ],
              ],
            ),
          ),
        ),
        BottomContinueButton(
          enabled: true,
          onTap: widget.onContinue,
          label: 'Continue',
        ),
      ],
    );
  }
}
