import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/timetable_entry.dart';
import '../timetable_manager.dart';
import 'app_colors.dart';
import 'app_theme.dart';
import 'design_tokens.dart';
import 'visual_skin.dart';
import 'visual_theme.dart';

/// Centralized reusable UI component catalog for Schedly.
/// Every component delegates directly to the active [VisualSkin] for styling and geometry.
class ThemedLectureCard extends StatefulWidget {
  final List<TimetableEntry> entries;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final void Function(TimetableEntry entry)? onEntryTap;
  final void Function(TimetableEntry entry)? onEntryLongPress;
  final bool Function(TimetableEntry entry)? canEditEntry;
  final bool isEditMode;
  final bool isHighlighted;

  const ThemedLectureCard({
    super.key,
    required this.entries,
    this.onTap,
    this.onLongPress,
    this.onEntryTap,
    this.onEntryLongPress,
    this.canEditEntry,
    this.isEditMode = false,
    this.isHighlighted = false,
  });

  @override
  State<ThemedLectureCard> createState() => _ThemedLectureCardState();
}

class _ThemedLectureCardState extends State<ThemedLectureCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _pressController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _pressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.975).animate(
      CurvedAnimation(
        parent: _pressController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _pressController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onTap != null || widget.onLongPress != null) {
      _pressController.forward();
    }
  }

  void _handleTapUp(TapUpDetails _) {
    _pressController.reverse();
  }

  void _handleTapCancel() {
    _pressController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final skin = VisualSkin.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sem = Theme.of(context).extension<AppSemanticColors>();
    final cancelledColor = sem?.cancelled ?? const Color(0xFFEF4444);

    final entries = widget.entries;
    final allCancelled = entries.every((e) => !e.isActive);
    final activeEntry = entries.firstWhere(
      (e) => e.isActive,
      orElse: () => entries.first,
    );

    final subjectColor = allCancelled
        ? cancelledColor
        : AppTheme.lectureTypeColor(
            context,
            subject: activeEntry.subject,
            component: activeEntry.component,
          );

    final cardDecoration = skin.cardRecipe.decoration(
      context: context,
      leftRailColor: subjectColor,
      isCancelled: allCancelled,
      isHighlighted: widget.isHighlighted,
    );

    return AnimatedBuilder(
      animation: _pressController,
      builder: (context, child) {
        return Transform.scale(scale: _scaleAnimation.value, child: child);
      },
      child: GestureDetector(
        behavior: (widget.onTap != null || widget.onLongPress != null)
            ? HitTestBehavior.opaque
            : HitTestBehavior.deferToChild,
        onTapDown: (widget.onTap != null || widget.onLongPress != null)
            ? _handleTapDown
            : null,
        onTapUp: (widget.onTap != null || widget.onLongPress != null)
            ? _handleTapUp
            : null,
        onTapCancel: (widget.onTap != null || widget.onLongPress != null)
            ? _handleTapCancel
            : null,
        onTap: widget.onTap,
        onLongPress: widget.onLongPress,
        child: ClipRRect(
          borderRadius: skin.cardRecipe.borderRadius,
          child: Container(
            decoration: cardDecoration,
            child: Stack(
              children: [
                if (skin.cardRecipe.leftRailWidth > 0)
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: skin.cardRecipe.leftRailWidth,
                    child: Container(color: subjectColor),
                  ),
                Padding(
                  padding: skin.cardRecipe.padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: entries.asMap().entries.map((mapEntry) {
                      final idx = mapEntry.key;
                      final entry = mapEntry.value;
                      final isCancelled = !entry.isActive;

                      final entryColor = isCancelled
                          ? cancelledColor
                          : AppTheme.lectureTypeColor(
                              context,
                              subject: entry.subject,
                              component: entry.component,
                            );

                      final iconData = skin.getSubjectIcon(
                        entry.subject,
                        component: entry.component,
                      );

                      final typeLabel = entry.component.trim().isNotEmpty
                          ? entry.component.trim()
                          : 'Theory';

                      final rowContent = Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Themed prominent icon container
                          skin.iconRecipe.buildContainer(
                            context,
                            icon: isCancelled ? Icons.cancel_rounded : iconData,
                            color: entryColor,
                            isCancelled: isCancelled,
                            size: 48,
                          ),
                          const SizedBox(width: 14),

                          // Title, Badges, and Metadata
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header row: Subject + Type Badge
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        entry.displaySubject,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: _titleStyleForSkin(
                                          skin,
                                          isCancelled: isCancelled,
                                          isDark: isDark,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    skin.badgeRecipe.buildBadge(
                                      context,
                                      label: isCancelled
                                          ? 'CANCELLED'
                                          : typeLabel,
                                      color: isCancelled
                                          ? cancelledColor
                                          : entryColor,
                                      isCancelled: isCancelled,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),

                                // Metadata wrap: Time, Room, Batch
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    _MetadataItem(
                                      icon: Icons.access_time_rounded,
                                      text: TimetableManager.formatTime(
                                        entry.startTime,
                                        entry.endTime,
                                      ),
                                      skin: skin,
                                    ),
                                    if (entry.room != null &&
                                        entry.room!.trim().isNotEmpty)
                                      _MetadataItem(
                                        icon: Icons.room_rounded,
                                        text: 'Room ${entry.room}',
                                        skin: skin,
                                      ),
                                    if (entry.batch != 'Whole Class')
                                      _MetadataItem(
                                        icon: Icons.group_rounded,
                                        text: entry.batch,
                                        skin: skin,
                                        isHighlight: true,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Optional trailing edit/options indicator
                          if (entries.length > 1 &&
                              widget.canEditEntry?.call(entry) == true)
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(
                                widget.isEditMode
                                    ? Icons.edit_rounded
                                    : Icons.more_vert_rounded,
                                size: 18,
                                color: skin.textMuted.withOpacity(0.6),
                              ),
                            )
                          else if (entries.length == 1 &&
                              (widget.onTap != null ||
                                  widget.onLongPress != null))
                            Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: Icon(
                                widget.isEditMode
                                    ? Icons.edit_rounded
                                    : Icons.more_vert_rounded,
                                size: 18,
                                color: skin.textMuted.withOpacity(0.6),
                              ),
                            ),
                        ],
                      );

                      final interactiveRow =
                          (entries.length > 1 &&
                              widget.canEditEntry?.call(entry) == true)
                          ? GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onEntryTap != null
                                  ? () => widget.onEntryTap!(entry)
                                  : null,
                              onLongPress: widget.onEntryLongPress != null
                                  ? () => widget.onEntryLongPress!(entry)
                                  : null,
                              child: rowContent,
                            )
                          : rowContent;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (idx > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10.0,
                              ),
                              child: Divider(
                                color: skin.borderLine.withOpacity(0.5),
                                height: 1,
                                thickness: 0.8,
                              ),
                            ),
                          interactiveRow,
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _titleStyleForSkin(
    VisualSkin skin, {
    required bool isCancelled,
    required bool isDark,
  }) {
    final baseColor = isCancelled
        ? const Color(0xFFEF4444)
        : (isDark ? Colors.white : const Color(0xFF1F1F1F));

    switch (skin.visualTheme) {
      case SchedlyVisualTheme.heritage:
        return TextStyle(
          fontFamily: 'Newsreader',
          fontFamilyFallback: const ['Playfair Display', 'Georgia', 'serif'],
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: baseColor,
          decoration: isCancelled ? TextDecoration.lineThrough : null,
        );
      case SchedlyVisualTheme.future:
        return TextStyle(
          fontFamily: 'Space Grotesk',
          fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
          fontSize: 17,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: baseColor,
          decoration: isCancelled ? TextDecoration.lineThrough : null,
        );
      case SchedlyVisualTheme.bloom:
        return TextStyle(
          fontFamily: 'Plus Jakarta Sans',
          fontFamilyFallback: const ['Outfit', 'Inter', 'sans-serif'],
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: baseColor,
          decoration: isCancelled ? TextDecoration.lineThrough : null,
        );
      case SchedlyVisualTheme.defaultTheme:
        return GoogleFonts.outfit(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: baseColor,
          decoration: isCancelled ? TextDecoration.lineThrough : null,
        );
    }
  }
}

class _MetadataItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final VisualSkin skin;
  final bool isHighlight;

  const _MetadataItem({
    required this.icon,
    required this.text,
    required this.skin,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isHighlight ? skin.primaryAccent : skin.textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontFamily: skin.visualTheme == SchedlyVisualTheme.heritage
                ? 'Newsreader'
                : skin.visualTheme == SchedlyVisualTheme.future
                ? 'Space Grotesk'
                : 'Inter',
            fontSize: 12,
            fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Themed day selector bar (Mon, Tue, Wed, Thu, Fri, Sat) matching the user reference design.
class ThemedDaySelector extends StatelessWidget {
  final List<String> days;
  final int selectedIndex;
  final int todayIndex;
  final ValueChanged<int> onDaySelected;

  const ThemedDaySelector({
    super.key,
    required this.days,
    required this.selectedIndex,
    required this.todayIndex,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final skin = VisualSkin.of(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(days.length, (index) {
        final isSelected = selectedIndex == index;
        final isToday = todayIndex == index;

        return skin.daySelectorRecipe.buildDayPill(
          context,
          dayName: days[index],
          isSelected: isSelected,
          isToday: isToday,
          onTap: () => onDaySelected(index),
        );
      }),
    );
  }
}

/// Themed screen header matching the reference design layout:
/// "Timetable", "Your schedule for the week", calendar icon, "Long-press to edit" pill.
class ThemedTimetableHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isEditMode;
  final VoidCallback? onCalendarTap;
  final VoidCallback? onEditModeToggle;

  const ThemedTimetableHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.isEditMode = false,
    this.onCalendarTap,
    this.onEditModeToggle,
  });

  @override
  Widget build(BuildContext context) {
    final skin = VisualSkin.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: skin.headerRecipe.titleStyle),
              const SizedBox(height: 2),
              Text(subtitle, style: skin.headerRecipe.subtitleStyle),
            ],
          ),
        ),
        if (onCalendarTap != null) ...[
          GestureDetector(
            onTap: onCalendarTap,
            child: Container(
              padding: const EdgeInsets.all(7.5),
              decoration: BoxDecoration(
                color: skin.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: skin.borderLine, width: 0.8),
              ),
              child: Icon(
                Icons.calendar_month_rounded,
                size: 17,
                color: skin.primaryAccent,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (onEditModeToggle != null)
          skin.headerRecipe.buildActionPill(
            context,
            label: isEditMode ? 'Done editing' : 'Long-press to edit',
            icon: Icons.edit_rounded,
            onTap: onEditModeToggle,
          ),
      ],
    );
  }
}
