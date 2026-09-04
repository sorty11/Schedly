import '../../user_roles.dart';
import '../models/tutorial_tour.dart';
import '../models/tutorial_step.dart';

/// Central registry for all Schedly tutorial tours and contextual feature discovery guides.
/// Future versions (V12, V13) can register new tours and features without altering the core engine.
class TutorialRegistry {
  static final Map<String, TutorialTour> _tours = {};
  static bool _initialized = false;

  /// Registers a tutorial tour. Overwrites existing tour with same ID if re-registered.
  static void registerTour(TutorialTour tour) {
    _tours[tour.tourId] = tour;
  }

  /// Retrieves a registered tour by its unique ID.
  static TutorialTour? getTour(String tourId) {
    _ensureDefaultToursRegistered();
    return _tours[tourId];
  }

  /// Retrieves all tours applicable to a given user role.
  static List<TutorialTour> getToursForRole(UserRole role) {
    _ensureDefaultToursRegistered();
    return _tours.values.where((t) => t.targetRole == null || t.targetRole == role).toList();
  }

  /// Retrieves replayable tours grouped for the Help & Tutorials center.
  static List<TutorialTour> getReplayableTours(UserRole role) {
    _ensureDefaultToursRegistered();
    return _tours.values.where((t) {
      if (t.targetRole != null && t.targetRole != role) return false;
      return true;
    }).toList();
  }

  /// Ensures default Schedly V11 tours are populated.
  static void _ensureDefaultToursRegistered() {
    if (_initialized) return;
    _initialized = true;

    // ── 1. Student Getting Started Tour ──────────────────────────────────────
    registerTour(const TutorialTour(
      tourId: 'student_tour',
      name: 'Getting Started with Schedly',
      description: 'Learn how to view lectures, track attendance, and customize your schedule.',
      targetRole: UserRole.student,
      category: TutorialCategory.gettingStarted,
      steps: [
        TutorialStep(
          targetId: 'dashboard_tab',
          title: 'Daily Dashboard',
          description: 'Your upcoming lectures, schedule overview, and live class status at a glance.',
          ccMessage: 'Welcome to Schedly! Here is your home base.',
          preferredPosition: TooltipPosition.top,
        ),
        TutorialStep(
          targetId: 'timetable_tab',
          title: 'Weekly Timetable',
          description: 'View your full schedule for the week. Swipe horizontally or tap days to navigate.',
          ccMessage: 'Never miss a room or timing change.',
          preferredPosition: TooltipPosition.top,
        ),
        TutorialStep(
          targetId: 'attendance_tab',
          title: 'Smart Attendance',
          description: 'Track subject percentages, see safe skip limits, or import your official attendance PDF.',
          ccMessage: 'Know exactly how many lectures you can miss.',
          preferredPosition: TooltipPosition.top,
        ),
        TutorialStep(
          targetId: 'announcements_tab',
          title: 'Updates & Notices',
          description: 'Stay informed with official section broadcasts and real-time faculty announcements.',
          ccMessage: 'Important alerts land right here.',
          preferredPosition: TooltipPosition.top,
        ),
        TutorialStep(
          targetId: 'profile_tab',
          title: 'Themes & Settings',
          description: 'Switch between 4 visual skins (Classic, Heritage, Neo Future, Bloom) and manage your account.',
          ccMessage: 'Make Schedly look and feel yours.',
          preferredPosition: TooltipPosition.top,
        ),
      ],
    ));

    // ── 2. CR Getting Started Tour ───────────────────────────────────────────
    registerTour(const TutorialTour(
      tourId: 'cr_tour',
      name: 'CR Command Center Guide',
      description: 'Master class timetable management, lecture edits, announcements, and rosters.',
      targetRole: UserRole.cr,
      category: TutorialCategory.management,
      steps: [
        TutorialStep(
          targetId: 'dashboard_tab',
          title: 'Section Dashboard',
          description: 'Quick snapshot of today’s class progress, timetable health, and active lectures.',
          ccMessage: 'You are the Class Representative. Let\'s explore your controls.',
          preferredPosition: TooltipPosition.top,
        ),
        TutorialStep(
          targetId: 'timetable_tab',
          title: 'Published Timetable',
          description: 'Preview the timetable as your students see it with live overrides.',
          ccMessage: 'Check the real-time schedule anytime.',
          preferredPosition: TooltipPosition.top,
        ),
        TutorialStep(
          targetId: 'attendance_tab',
          title: 'Section Attendance',
          description: 'Monitor overall attendance data and course hours configuration.',
          ccMessage: 'Keep attendance tracking healthy.',
          preferredPosition: TooltipPosition.top,
        ),
        TutorialStep(
          targetId: 'admin_tab',
          title: 'CR Control Panel',
          description: 'Access Timetable Studio, lecture replacement, broadcast announcements, and class rosters.',
          ccMessage: 'This is where you manage your section.',
          preferredPosition: TooltipPosition.top,
        ),
        TutorialStep(
          targetId: 'announcements_tab',
          title: 'Class Broadcasts',
          description: 'Send urgent notifications to all registered students in your division instantly.',
          ccMessage: 'Keep everyone updated.',
          preferredPosition: TooltipPosition.top,
        ),
        TutorialStep(
          targetId: 'profile_tab',
          title: 'Themes & Security',
          description: 'Customize appearance and access role credentials and help resources.',
          ccMessage: 'Manage your section settings.',
          preferredPosition: TooltipPosition.top,
        ),
      ],
    ));

    // ── 3. SR Getting Started Tour ───────────────────────────────────────────
    registerTour(const TutorialTour(
      tourId: 'sr_tour',
      name: 'SR Subject Guide',
      description: 'Manage subject conduct, verify held sessions, and liaise with faculty.',
      targetRole: UserRole.sr,
      category: TutorialCategory.management,
      steps: [
        TutorialStep(
          targetId: 'dashboard_tab',
          title: 'SR Dashboard',
          description: 'View upcoming lectures for your assigned subject and quick action items.',
          ccMessage: 'Subject Representative controls activated.',
          preferredPosition: TooltipPosition.top,
        ),
        TutorialStep(
          targetId: 'timetable_tab',
          title: 'Timetable Overview',
          description: 'See when your subject lectures and labs are scheduled across the week.',
          ccMessage: 'Plan sessions seamlessly.',
          preferredPosition: TooltipPosition.top,
        ),
        TutorialStep(
          targetId: 'admin_tab',
          title: 'SR Control Panel',
          description: 'Manage subject conduct, verify lectures, and access assigned faculty details.',
          ccMessage: 'Verify whether lectures were conducted, cancelled, or rescheduled.',
          preferredPosition: TooltipPosition.top,
        ),
        TutorialStep(
          targetId: 'announcements_tab',
          title: 'Notifications',
          description: 'Receive alerts when faculty or CRs propose lecture adjustments for your course.',
          ccMessage: 'Stay on top of schedule changes.',
          preferredPosition: TooltipPosition.top,
        ),
        TutorialStep(
          targetId: 'profile_tab',
          title: 'Profile & Themes',
          description: 'Switch visual skins and access the Tutorial Replay Center.',
          ccMessage: 'Customize your experience.',
          preferredPosition: TooltipPosition.top,
        ),
      ],
    ));

    // ── 4. Faculty Getting Started Tour ──────────────────────────────────────
    registerTour(const TutorialTour(
      tourId: 'faculty_tour',
      name: 'Faculty Portal Guide',
      description: 'Navigate your teaching schedule, sections, SR connections, and lecture requests.',
      targetRole: UserRole.faculty,
      category: TutorialCategory.gettingStarted,
      steps: [
        TutorialStep(
          targetId: 'faculty_home_tab',
          title: 'Today’s Lectures',
          description: 'Live countdown to your next class and today’s consolidated teaching agenda.',
          ccMessage: 'Welcome Professor! Here is your teaching cockpit.',
          preferredPosition: TooltipPosition.top,
        ),
        TutorialStep(
          targetId: 'faculty_timetable_tab',
          title: 'Master Teaching Timetable',
          description: 'Consolidated view of all your assigned sections with real-time CR overrides reflected.',
          ccMessage: 'See your complete teaching commitments across all sections.',
          preferredPosition: TooltipPosition.top,
        ),
        TutorialStep(
          targetId: 'faculty_panel_tab',
          title: 'Faculty Control Panel',
          description: 'Manage your sections, connect with Subject Representatives, detect timetable conflicts, and request extra sessions.',
          ccMessage: 'Collaborate directly with student representatives.',
          preferredPosition: TooltipPosition.top,
        ),
        TutorialStep(
          targetId: 'faculty_profile_tab',
          title: 'Faculty Profile',
          description: 'Cabin information, department details, visual skins, and Help Center.',
          ccMessage: 'Keep your academic contact info up to date.',
          preferredPosition: TooltipPosition.top,
        ),
      ],
    ));
  }
}

