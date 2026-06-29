import 'package:flutter/material.dart';
import '../../user_roles.dart';
import 'tutorial_storage_service.dart';
import 'tutorial_controller.dart';
import '../models/tutorial_tour.dart';
import '../models/tutorial_step.dart';
import '../widgets/tutorial_overlay.dart';
import '../widgets/welcome_card.dart';

class OnboardingService {
  static final OnboardingService instance = OnboardingService._();
  OnboardingService._();

  Future<void> initializeAndCheckFirstLaunch(BuildContext context, UserRole role) async {
    final hasSeenWelcome = await TutorialStorageService.hasSeenTour('welcome');
    if (!hasSeenWelcome) {
      if (!context.mounted) return;
      _showWelcomeCard(context, role);
    } else {
      // Check if they need the role tour if they skipped it initially?
      // Or just wait for contextual tours
    }
  }

  void _showWelcomeCard(BuildContext context, UserRole role) {
    String message = '';
    if (role == UserRole.student) {
      message = "Your smart academic companion.";
    } else if (role == UserRole.sr) {
      message = "Let's help you manage your subject.";
    } else {
      message = "You control your academic section.";
    }

    OverlayEntry? entry;
    entry = OverlayEntry(
      builder: (context) => WelcomeCard(
        roleMessage: message,
        onStartTour: () async {
          entry?.remove();
          await TutorialStorageService.markTourSeen('welcome');
          if (context.mounted) startRoleTour(context, role);
        },
        onSkip: () async {
          entry?.remove();
          await TutorialStorageService.markTourSeen('welcome');
        },
      ),
    );
    Overlay.of(context).insert(entry);
  }

  void startRoleTour(BuildContext context, UserRole role) {
    TutorialTour? tour;
    if (role == UserRole.student) {
      tour = _studentTour();
    } else if (role == UserRole.sr) {
      tour = _srTour();
    } else if (role == UserRole.cr) {
      tour = _crTour();
    }
    
    if (tour != null) {
      TutorialOverlayManager.show(context);
      TutorialController.instance.startTour(tour);
    }
  }

  TutorialTour _studentTour() {
    return const TutorialTour(
      tourId: 'student_tour',
      name: 'Getting Started',
      steps: [
        TutorialStep(
          targetId: 'dashboard_tab',
          title: 'Your Dashboard',
          description: 'Here you can see your upcoming lectures and daily schedule at a glance.',
          ccMessage: 'Welcome to Schedly!',
        ),
        TutorialStep(
          targetId: 'timetable_tab',
          title: 'Weekly Timetable',
          description: 'Tap here to view your entire week.',
          ccMessage: 'Let\'s see what\'s next.',
          requireInteraction: true,
        ),
        TutorialStep(
          targetId: 'analytics_tab',
          title: 'Semester Analytics',
          description: 'Keep track of how many lectures are completed or pending.',
          ccMessage: 'Stay on top of your attendance!',
        ),
        TutorialStep(
          targetId: 'profile_tab',
          title: 'Your Profile',
          description: 'Customize your theme and manage your account.',
        ),
      ],
    );
  }

  TutorialTour _srTour() {
    return const TutorialTour(
      tourId: 'sr_tour',
      name: 'Subject Representative Guide',
      steps: [
        TutorialStep(
          targetId: 'dashboard_tab',
          title: 'SR Dashboard',
          description: 'As an SR, your dashboard highlights lectures waiting for your verification.',
          ccMessage: 'You have special permissions now.',
        ),
        TutorialStep(
          targetId: 'conduct_dashboard_tab',
          title: 'Conduct Dashboard',
          description: 'Tap here to manage all lectures for your assigned subject.',
          requireInteraction: true,
        ),
      ],
    );
  }

  TutorialTour _crTour() {
    return const TutorialTour(
      tourId: 'cr_tour',
      name: 'Class Representative Guide',
      steps: [
        TutorialStep(
          targetId: 'cr_panel_btn',
          title: 'CR Control Panel',
          description: 'Tap here to access your powerful class management tools.',
          ccMessage: 'You are in control.',
          requireInteraction: true,
        ),
        TutorialStep(
          targetId: 'import_timetable_btn',
          title: 'Import Timetable',
          description: 'Upload the official PDF to automatically generate the schedule for everyone.',
        ),
        TutorialStep(
          targetId: 'manage_lectures_btn',
          title: 'Manage Lectures',
          description: 'Add, edit, or delete specific lectures if the schedule changes.',
        ),
        TutorialStep(
          targetId: 'create_announcement_btn',
          title: 'Announcements',
          description: 'Broadcast messages to your entire section instantly.',
        ),
      ],
    );
  }

  Future<void> checkAnalyticsContext(BuildContext context) async {
    if (TutorialController.instance.isVisible) return; 
    if (await TutorialStorageService.hasSeenTour('analytics_context')) return;
    if (await TutorialStorageService.hasMastery('analytics')) return;

    if (!context.mounted) return;
    
    final tour = const TutorialTour(
      tourId: 'analytics_context',
      name: 'Understanding Analytics',
      steps: [
        TutorialStep(
          targetId: 'health_card',
          title: 'Semester Progress',
          description: 'This shows your overall completion rate across all subjects.',
          ccMessage: 'Let\'s review your progress.',
        ),
        TutorialStep(
          targetId: 'subject_breakdown',
          title: 'Subject Breakdown',
          description: 'See detailed stats for completed and remaining lectures per subject.',
        ),
      ],
    );
    
    TutorialOverlayManager.show(context);
    TutorialController.instance.startTour(tour);
    await TutorialStorageService.markTourSeen('analytics_context');
    await TutorialStorageService.markMastery('analytics');
  }
}
