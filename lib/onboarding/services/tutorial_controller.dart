import 'package:flutter/widgets.dart';
import '../models/tutorial_tour.dart';
import '../models/tutorial_step.dart';
import '../widgets/tutorial_target.dart';
import 'tutorial_storage_service.dart';

enum TutorialState {
  idle,
  preparing,
  waitingForTarget,
  transitioning,
  highlighting,
  waitingForInteraction,
  interactionCompleted,
  celebration,
  paused,
}

class TutorialController extends ChangeNotifier with WidgetsBindingObserver {
  static final TutorialController instance = TutorialController._();
  TutorialController._() {
    TargetRegistry.instance.addListener(_onTargetRegistryUpdated);
    WidgetsBinding.instance.addObserver(this);
  }

  TutorialTour? _activeTour;
  int _currentStepIndex = 0;
  TutorialState _state = TutorialState.idle;
  TutorialState? _prePauseState;

  TutorialTour? get activeTour => _activeTour;
  int get currentStepIndex => _currentStepIndex;
  TutorialState get state => _state;
  bool get isVisible =>
      _state != TutorialState.idle && _state != TutorialState.paused;

  TutorialStep? get currentStep {
    if (_activeTour == null || _currentStepIndex >= _activeTour!.steps.length)
      return null;
    return _activeTour!.steps[_currentStepIndex];
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _resumeTour();
    } else {
      _pauseTour();
    }
  }

  void startTour(TutorialTour tour) {
    _activeTour = tour;
    _currentStepIndex = 0;
    _transitionTo(TutorialState.preparing);

    // Give UI a frame to prepare
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _evaluateCurrentStep();
    });
  }

  void completeStep() {
    if (_state == TutorialState.waitingForInteraction ||
        _state == TutorialState.highlighting) {
      _transitionTo(TutorialState.interactionCompleted);

      // Briefly show celebration, then advance
      Future.delayed(const Duration(milliseconds: 200), () {
        if (_state == TutorialState.interactionCompleted) {
          _transitionTo(TutorialState.celebration);
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (_state == TutorialState.celebration) {
              advanceStep();
            }
          });
        }
      });
    }
  }

  void advanceStep() {
    if (_activeTour == null) return;

    if (_currentStepIndex < _activeTour!.steps.length - 1) {
      _currentStepIndex++;
      _evaluateCurrentStep();
    } else {
      finishTour();
    }
  }

  void previousStep() {
    if (_currentStepIndex > 0) {
      _currentStepIndex--;
      _evaluateCurrentStep();
    }
  }

  void finishTour() {
    if (_activeTour != null) {
      TutorialStorageService.markTourSeen(_activeTour!.tourId);
    }
    _activeTour = null;
    _currentStepIndex = 0;
    _transitionTo(TutorialState.idle);
  }

  void skipTour() {
    finishTour();
  }

  void retryCurrentStep() {
    _evaluateCurrentStep();
  }

  void _pauseTour() {
    if (_state != TutorialState.idle && _state != TutorialState.paused) {
      _prePauseState = _state;
      _transitionTo(TutorialState.paused);
    }
  }

  void _resumeTour() {
    if (_state == TutorialState.paused && _prePauseState != null) {
      _transitionTo(_prePauseState!);
      if (_state == TutorialState.waitingForTarget) {
        _evaluateCurrentStep();
      }
    }
  }

  void _evaluateCurrentStep() {
    final step = currentStep;
    if (step == null) return;

    _transitionTo(TutorialState.waitingForTarget);
    _checkTargetAvailability();

    // Recovery timeout
    Future.delayed(const Duration(seconds: 3), () {
      if (_state == TutorialState.waitingForTarget && _activeTour != null) {
        advanceStep();
      }
    });
  }

  void _onTargetRegistryUpdated() {
    if (_state == TutorialState.waitingForTarget) {
      _checkTargetAvailability();
    } else if (_state == TutorialState.highlighting ||
        _state == TutorialState.waitingForInteraction) {
      // If target disappears while highlighting, fallback to waiting
      final bounds = TargetRegistry.instance.getBounds(currentStep!.targetId);
      if (bounds == null) {
        _transitionTo(TutorialState.waitingForTarget);
      }
    }
  }

  void _checkTargetAvailability() {
    final step = currentStep;
    if (step == null) return;

    final key = TargetRegistry.instance.getKey(step.targetId);
    if (key != null &&
        key.currentContext != null &&
        key.currentContext!.mounted) {
      try {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
      } catch (e) {
        // Not in a scrollable or already visible
      }
    }

    final bounds = TargetRegistry.instance.getBounds(step.targetId);
    if (bounds != null) {
      _transitionTo(TutorialState.transitioning);
      // Wait for transition animation to complete
      Future.delayed(const Duration(milliseconds: 400), () {
        if (_state == TutorialState.transitioning) {
          if (step.requireInteraction) {
            _transitionTo(TutorialState.waitingForInteraction);
          } else {
            _transitionTo(TutorialState.highlighting);
          }
        }
      });
    }
  }

  void _transitionTo(TutorialState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    TargetRegistry.instance.removeListener(_onTargetRegistryUpdated);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
