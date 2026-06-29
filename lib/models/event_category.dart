enum EventCategory {
  academic,
  breakTime,
  lunch,
  holiday,
  activity,
  event,
  library,
  mentoring,
  sports,
  freeSlot
}

extension EventCategoryExtension on EventCategory {
  String get name {
    switch (this) {
      case EventCategory.academic:
        return 'Academic';
      case EventCategory.breakTime:
        return 'Break';
      case EventCategory.lunch:
        return 'Lunch';
      case EventCategory.holiday:
        return 'Holiday';
      case EventCategory.activity:
        return 'Activity';
      case EventCategory.event:
        return 'Event';
      case EventCategory.library:
        return 'Library';
      case EventCategory.mentoring:
        return 'Mentoring';
      case EventCategory.sports:
        return 'Sports';
      case EventCategory.freeSlot:
        return 'Free Slot';
    }
  }

  static EventCategory fromString(String val) {
    switch (val.toLowerCase()) {
      case 'academic':
        return EventCategory.academic;
      case 'break':
      case 'breaktime':
        return EventCategory.breakTime;
      case 'lunch':
        return EventCategory.lunch;
      case 'holiday':
        return EventCategory.holiday;
      case 'activity':
        return EventCategory.activity;
      case 'event':
        return EventCategory.event;
      case 'library':
        return EventCategory.library;
      case 'mentoring':
        return EventCategory.mentoring;
      case 'sports':
        return EventCategory.sports;
      case 'free slot':
      case 'freeslot':
        return EventCategory.freeSlot;
      default:
        return EventCategory.academic;
    }
  }

  static EventCategory inferFromSubject(String subject) {
    final l = subject.toLowerCase();
    if (l.contains('lunch')) return EventCategory.lunch;
    if (l.contains('free slot') || l.contains('freeslot')) return EventCategory.freeSlot;
    if (l.contains('break')) return EventCategory.breakTime;
    if (l.contains('mentor')) return EventCategory.mentoring;
    if (l.contains('sport')) return EventCategory.sports;
    if (l.contains('library')) return EventCategory.library;
    if (l.contains('activity') || l.contains('club')) return EventCategory.activity;
    return EventCategory.academic;
  }
}
