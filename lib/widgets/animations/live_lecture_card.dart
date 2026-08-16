import 'dart:async';
import 'package:flutter/material.dart';
import '../../theme/theme.dart';

/// The currently-active lecture card.
/// Clean, emphasized surface — not a gradient hero.
/// Inspired by Google Calendar's current event presentation.
class LiveLectureCard extends StatefulWidget {
  final String subject;
  final String time;
  final String room;
  final String? facultyName;
  final VoidCallback? onFacultyTap;
  final VoidCallback? onTap;

  const LiveLectureCard({
    super.key,
    required this.subject,
    required this.time,
    required this.room,
    this.facultyName,
    this.onFacultyTap,
    this.onTap,
  });

  @override
  State<LiveLectureCard> createState() => _LiveLectureCardState();
}

class _LiveLectureCardState extends State<LiveLectureCard> {
  Timer? _progressTimer;
  double _progressValue = 0.0;

  @override
  void initState() {
    super.initState();
    _updateProgress();
    _progressTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _updateProgress();
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _updateProgress() {
    final now = DateTime.now();
    final parsed = _parseTimeRange(widget.time);
    if (parsed == null) return;

    final startMinutes = parsed.$1;
    final endMinutes = parsed.$2;
    final currentMinutes = now.hour * 60 + now.minute;

    if (endMinutes <= startMinutes) return;
    final elapsed = currentMinutes - startMinutes;
    final total = endMinutes - startMinutes;
    final progress = (elapsed / total).clamp(0.0, 1.0);

    if (mounted) setState(() => _progressValue = progress);
  }

  (int, int)? _parseTimeRange(String timeStr) {
    try {
      final parts = timeStr.split('-');
      if (parts.length < 2) return null;

      int parseTime(String raw) {
        final cleaned = raw.trim().toLowerCase();
        final isPM = cleaned.contains('pm');
        final isAM = cleaned.contains('am');
        final digits = cleaned.replaceAll(RegExp(r'[^0-9:]'), '');
        final hm = digits.split(':');
        int h = int.parse(hm[0]);
        int m = hm.length > 1 ? int.parse(hm[1]) : 0;
        if (isPM && h != 12) h += 12;
        if (isAM && h == 12) h = 0;
        if (!isPM && !isAM && h >= 1 && h <= 7) h += 12;
        return h * 60 + m;
      }

      return (parseTime(parts[0]), parseTime(parts[1]));
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sem = Theme.of(context).extension<AppSemanticColors>()!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark ? colorScheme.surfaceContainerHighest : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF2E2E2E)
        : const Color(0xFFE5E7EB);

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left color strip (Google Calendar style)
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: colorScheme.primary,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.lg),
                    bottomLeft: Radius.circular(AppRadius.lg),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status row — LIVE pill + time
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: sem.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                              border: Border.all(
                                color: sem.success.withValues(alpha: 0.2),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                    color: sem.success,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'LIVE',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: sem.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.access_time_rounded,
                                size: 14,
                                color: sem.onSurfaceMuted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.time,
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: sem.onSurfaceMuted,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.md),

                      Text(
                        widget.subject,
                        style: TextStyle(
                          fontFamily:
                              'Inter', // Inter instead of Outfit for high density clarity
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                          height: 1.2,
                          letterSpacing: -0.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),

                      const SizedBox(height: AppSpacing.md),

                      Row(
                        children: [
                          _MetaText(
                            icon: Icons.room_rounded,
                            label: widget.room,
                            sem: sem,
                          ),
                          if (widget.facultyName != null &&
                              widget.facultyName!.isNotEmpty) ...[
                            const SizedBox(width: AppSpacing.md),
                            GestureDetector(
                              onTap: widget.onFacultyTap,
                              child: _MetaText(
                                icon: Icons.person_outline_rounded,
                                label: widget.facultyName!,
                                sem: sem,
                                isAccent: true,
                                colorScheme: colorScheme,
                              ),
                            ),
                          ],
                        ],
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: LinearProgressIndicator(
                          value: _progressValue,
                          minHeight: 4,
                          backgroundColor: colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  final IconData icon;
  final String label;
  final AppSemanticColors sem;
  final bool isAccent;
  final ColorScheme? colorScheme;

  const _MetaText({
    required this.icon,
    required this.label,
    required this.sem,
    this.isAccent = false,
    this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = isAccent && colorScheme != null
        ? colorScheme!.primary
        : sem.onSurfaceMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: fgColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: fgColor,
          ),
        ),
      ],
    );
  }
}
