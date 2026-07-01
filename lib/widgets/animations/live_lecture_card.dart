import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/theme.dart';

/// A premium card for the currently active lecture.
/// Shows a pulsing live dot, subject name, time, room,
/// and a real-time elapsed progress bar.
class LiveLectureCard extends StatefulWidget {
  final String subject;
  final String time;
  final String room;
  final VoidCallback? onTap;

  const LiveLectureCard({
    super.key,
    required this.subject,
    required this.time,
    required this.room,
    this.onTap,
  });

  @override
  State<LiveLectureCard> createState() => _LiveLectureCardState();
}

class _LiveLectureCardState extends State<LiveLectureCard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _hoverController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _hoverScale;
  late Animation<double> _hoverY;

  Timer? _progressTimer;
  double _progressValue = 0.0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );

    _hoverController = AnimationController(
      vsync: this,
      duration: AppDuration.standard,
    );

    _hoverScale = Tween<double>(begin: 1.0, end: 1.015).animate(
      CurvedAnimation(parent: _hoverController, curve: AppCurves.standard),
    );
    _hoverY = Tween<double>(begin: 0.0, end: -3.0).animate(
      CurvedAnimation(parent: _hoverController, curve: AppCurves.standard),
    );

    _updateProgress();
    _progressTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _updateProgress();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _hoverController.dispose();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) => _hoverController.forward(),
      onExit: (_) => _hoverController.reverse(),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pulseController, _hoverController]),
          builder: (context, child) {
            return Transform(
              transform: Matrix4.translationValues(0.0, _hoverY.value, 0.0)
                ..multiply(Matrix4.diagonal3Values(_hoverScale.value, _hoverScale.value, 1.0)),
              alignment: Alignment.center,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  gradient: LinearGradient(
                    colors: isDark
                        ? [
                            const Color(0xFF2D2B6B),
                            const Color(0xFF1E1B4B),
                          ]
                        : [
                            colorScheme.primary,
                            colorScheme.secondary,
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(
                        alpha: isDark ? 0.3 : 0.35 + _hoverController.value * 0.1,
                      ),
                      blurRadius: 24 + _hoverController.value * 12,
                      offset: const Offset(0, 8),
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    // Background decoration circle
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 60,
                      bottom: -30,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.04),
                        ),
                      ),
                    ),

                    Padding(
                      padding: EdgeInsets.all(AppSpacing.x2l),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // LIVE pill
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: AppSpacing.md,
                                  vertical: AppSpacing.xs + 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppRadius.full),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _pulseAnimation,
                                      builder: (context, child) => Opacity(
                                        opacity: _pulseAnimation.value,
                                        child: Container(
                                          width: 7,
                                          height: 7,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFF4ADE80),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm - 2),
                                    Text(
                                      'IN PROGRESS',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.2,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // Subject name
                          Text(
                            widget.subject,
                            style: GoogleFonts.outfit(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                              letterSpacing: -0.5,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),

                          const SizedBox(height: AppSpacing.md),

                          // Time + Room
                          Row(
                            children: [
                              _buildInfoChip(
                                Icons.access_time_rounded,
                                widget.time,
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              _buildInfoChip(
                                Icons.room_rounded,
                                'Room ${widget.room}',
                              ),
                            ],
                          ),

                          const SizedBox(height: AppSpacing.lg),

                          // Progress bar
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Lecture Progress',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withValues(alpha: 0.65),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  Text(
                                    '${(_progressValue * 100).round()}%',
                                    style: GoogleFonts.outfit(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.sm - 2),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.full),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0, end: _progressValue),
                                  duration: const Duration(milliseconds: 800),
                                  curve: AppCurves.standard,
                                  builder: (context, value, child) {
                                    return LinearProgressIndicator(
                                      value: value,
                                      minHeight: 6,
                                      backgroundColor:
                                          Colors.white.withValues(alpha: 0.2),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm - 2,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.white.withValues(alpha: 0.85)),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
