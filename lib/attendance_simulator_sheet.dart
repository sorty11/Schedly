import 'package:flutter/material.dart';
import 'models/attendance_record.dart';
import 'models/intelligence_models.dart';
import 'services/attendance_intelligence_service.dart';
import 'theme/theme.dart';
import 'widgets/schedly_bottom_sheet.dart';
import 'widgets/schedly_card.dart';

class AttendanceSimulatorSheet extends StatefulWidget {
  final AttendanceRecord record;
  final SubjectIntelligence intelligence;

  const AttendanceSimulatorSheet({
    super.key,
    required this.record,
    required this.intelligence,
  });

  @override
  State<AttendanceSimulatorSheet> createState() => _AttendanceSimulatorSheetState();
}

class _AttendanceSimulatorSheetState extends State<AttendanceSimulatorSheet> {
  int _attendNext = 0;
  int _missNext = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final simulatedPct = AttendanceIntelligenceService.simulateScenario(
      widget.record,
      attendNext: _attendNext,
      missNext: _missNext,
    );

    Color projectedColor;
    if (simulatedPct >= 0.80) {
      projectedColor = sem.conducted;
    } else if (simulatedPct >= 0.75) {
      projectedColor = sem.warning;
    } else {
      projectedColor = sem.cancelled;
    }

    final diff = simulatedPct - widget.record.percentage;
    final isPositive = diff > 0;

    return SchedlyBottomSheet(
      padding: EdgeInsets.only(
        left: AppSpacing.x2l,
        right: AppSpacing.x2l,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.x2l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Scenario Simulator',
            style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700),
          ),
          Text(
            '${widget.record.subjectCode} ${widget.record.component}',
            style: TextStyle(fontFamily: 'Inter', fontSize: 14, color: sem.onSurfaceMuted),
          ),
          const SizedBox(height: AppSpacing.x3l),
          
          // Current vs Projected
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text('Current', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: sem.onSurfaceMuted)),
                  Text(
                    '${(widget.record.percentage * 100).round()}%',
                    style: TextStyle(fontFamily: 'Outfit', fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Icon(Icons.arrow_forward_rounded, color: sem.onSurfaceMuted),
              Column(
                children: [
                  Text('Projected', style: TextStyle(fontFamily: 'Inter', fontSize: 12, color: sem.onSurfaceMuted)),
                  Row(
                    children: [
                      Text(
                        '${(simulatedPct * 100).round()}%',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 32, fontWeight: FontWeight.w800, color: projectedColor),
                      ),
                      if (diff.abs() >= 0.005) ...[
                        const SizedBox(width: 4),
                        Icon(
                          isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                          size: 16,
                          color: isPositive ? sem.conducted : sem.cancelled,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: AppSpacing.x3l),
          
          // Controls
          SchedlyCard(
            variant: SchedlyCardVariant.standard,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                _StepperRow(
                  label: 'Attend next classes',
                  value: _attendNext,
                  color: sem.conducted,
                  onChanged: (val) => setState(() => _attendNext = val),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Divider(),
                ),
                _StepperRow(
                  label: 'Miss next classes',
                  value: _missNext,
                  color: sem.cancelled,
                  onChanged: (val) => setState(() => _missNext = val),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: AppSpacing.x3l),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Done', style: TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepperRow extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final ValueChanged<int> onChanged;

  const _StepperRow({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;

    return Row(
      children: [
        Expanded(
          child: Text(label, style: TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w500)),
        ),
        Row(
          children: [
            _CircleButton(
              icon: Icons.remove,
              onTap: value > 0 ? () => onChanged(value - 1) : null,
              isDark: isDark,
              sem: sem,
            ),
            SizedBox(
              width: 40,
              child: Text(
                '$value',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700, color: color),
              ),
            ),
            _CircleButton(
              icon: Icons.add,
              onTap: value < 20 ? () => onChanged(value + 1) : null,
              isDark: isDark,
              sem: sem,
            ),
          ],
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool isDark;
  final AppSemanticColors sem;

  const _CircleButton({required this.icon, this.onTap, required this.isDark, required this.sem});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: enabled 
          ? (isDark ? Colors.white12 : const Color(0xFFF3F4F6))
          : (isDark ? Colors.white.withValues(alpha: 0.02) : const Color(0xFFFAFAFA)),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            icon,
            size: 20,
            color: enabled ? (isDark ? Colors.white : Colors.black87) : sem.borderSubtle,
          ),
        ),
      ),
    );
  }
}
