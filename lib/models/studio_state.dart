import 'dart:convert';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// ENUMS
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

enum PeriodKind { lecture, breakTime, lunch, freePeriod }

enum SlotType { lecture, free, breakSlot, lunchSlot, holiday }

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PERIOD DEFINITION
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class PeriodDef {
  String id;
  String name;
  int startMinutes; // minutes from midnight
  int endMinutes;
  PeriodKind kind;

  PeriodDef({
    required this.id,
    required this.name,
    required this.startMinutes,
    required this.endMinutes,
    this.kind = PeriodKind.lecture,
  });

  bool get isBreak => kind == PeriodKind.breakTime || kind == PeriodKind.lunch;
  int get durationMinutes => endMinutes - startMinutes;

  PeriodDef copyWith({
    String? name,
    int? startMinutes,
    int? endMinutes,
    PeriodKind? kind,
  }) =>
      PeriodDef(
        id: id,
        name: name ?? this.name,
        startMinutes: startMinutes ?? this.startMinutes,
        endMinutes: endMinutes ?? this.endMinutes,
        kind: kind ?? this.kind,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'kind': kind.name,
      };

  static PeriodDef fromJson(Map<String, dynamic> j) => PeriodDef(
        id: j['id'] as String,
        name: j['name'] as String,
        startMinutes: j['startMinutes'] as int,
        endMinutes: j['endMinutes'] as int,
        kind: PeriodKind.values.firstWhere(
          (k) => k.name == j['kind'],
          orElse: () => PeriodKind.lecture,
        ),
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// SLOT STATE  (one slot = one period on one day)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class SlotState {
  final String periodId;
  SlotType type;
  String? subject;
  String? batch;
  String? room;
  String component; // Theory / Lab / Tutorial
  int durationPeriods; // For merged periods

  SlotState({
    required this.periodId,
    this.type = SlotType.lecture,
    this.subject,
    this.batch,
    this.room,
    this.component = 'Theory',
    this.durationPeriods = 1,
  });

  bool get isEmpty =>
      type == SlotType.lecture && (subject == null || subject!.isEmpty);

  bool get isFilled =>
      type == SlotType.lecture && subject != null && subject!.isNotEmpty;

  bool get isNonLecture => type != SlotType.lecture;

  SlotState copyWith({
    String? periodId,
    SlotType? type,
    String? subject,
    String? batch,
    String? room,
    String? component,
    int? durationPeriods,
  }) =>
      SlotState(
        periodId: periodId ?? this.periodId,
        type: type ?? this.type,
        subject: subject ?? this.subject,
        batch: batch ?? this.batch,
        room: room ?? this.room,
        component: component ?? this.component,
        durationPeriods: durationPeriods ?? this.durationPeriods,
      );

  Map<String, dynamic> toJson() => {
        'periodId': periodId,
        'type': type.name,
        'subject': subject,
        'batch': batch,
        'room': room,
        'component': component,
        'durationPeriods': durationPeriods,
      };

  static SlotState fromJson(Map<String, dynamic> j) => SlotState(
        periodId: j['periodId'] as String,
        type: SlotType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => SlotType.lecture,
        ),
        subject: j['subject'] as String?,
        batch: j['batch'] as String?,
        room: j['room'] as String?,
        component: (j['component'] as String?) ?? 'Theory',
        durationPeriods: (j['durationPeriods'] as int?) ?? 1,
      );
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// STUDIO DRAFT CONFIG   (the full in-memory + serialisable state)
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class StudioDraftConfig {
  List<String> selectedDays;
  List<String> batches;
  List<PeriodDef> periods;

  /// day → periodId → List of simultaneous lectures
  Map<String, Map<String, List<SlotState>>> slots;

  DateTime lastSaved;

  StudioDraftConfig({
    required this.selectedDays,
    required this.batches,
    required this.periods,
    required this.slots,
    required this.lastSaved,
  });

  // ── Defaults ───────────────────────────────────────────────────────────────
  static StudioDraftConfig blank() => StudioDraftConfig(
        selectedDays: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'],
        batches: ['Whole Class'],
        periods: [],
        slots: {},
        lastSaved: DateTime.now(),
      );

  // ── Serialisation ──────────────────────────────────────────────────────────
  Map<String, dynamic> toJson() => {
        'selectedDays': selectedDays,
        'batches': batches,
        'periods': periods.map((p) => p.toJson()).toList(),
        'slots': slots.map((day, periodMap) => MapEntry(
              day,
              periodMap.map((pid, list) => MapEntry(
                    pid,
                    list.map((s) => s.toJson()).toList(),
                  )),
            )),
        'lastSaved': lastSaved.toIso8601String(),
      };

  static StudioDraftConfig fromJson(Map<String, dynamic> j) {
    final slotsRaw = (j['slots'] as Map<String, dynamic>?) ?? {};
    return StudioDraftConfig(
      selectedDays: List<String>.from(j['selectedDays'] ?? []),
      batches: List<String>.from(j['batches'] ?? ['Whole Class']),
      periods: (j['periods'] as List<dynamic>? ?? [])
          .map((e) => PeriodDef.fromJson(e as Map<String, dynamic>))
          .toList(),
      slots: slotsRaw.map((day, periodMapRaw) {
        final pmMap = periodMapRaw as Map<String, dynamic>? ?? {};
        return MapEntry(
          day,
          pmMap.map((pid, listRaw) {
            final list = listRaw as List<dynamic>? ?? [];
            return MapEntry(
              pid,
              list.map((e) => SlotState.fromJson(e as Map<String, dynamic>)).toList(),
            );
          }),
        );
      }),
      lastSaved: DateTime.tryParse(j['lastSaved'] ?? '') ?? DateTime.now(),
    );
  }

  String toJsonString() => jsonEncode(toJson());

  static StudioDraftConfig fromJsonString(String raw) =>
      fromJson(jsonDecode(raw) as Map<String, dynamic>);

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Ensure all days and periods have their slot list initialised.
  void ensureSlotsInitialised() {
    for (final day in selectedDays) {
      if (!slots.containsKey(day)) {
        slots[day] = {};
      }
      for (final p in periods) {
        if (!slots[day]!.containsKey(p.id)) {
          slots[day]![p.id] = [];
        }
      }
    }
  }

  /// Count filled (has a lecture) academic periods for a day.
  /// A period is filled if it contains at least one lecture.
  int filledCount(String day) {
    final daySlots = slots[day] ?? {};
    final academicPeriods = periods.where((p) => !p.isBreak).map((p) => p.id).toSet();
    int count = 0;
    for (final pid in academicPeriods) {
      final periodList = daySlots[pid] ?? [];
      if (periodList.any((sl) => sl.isFilled)) {
        count++;
      }
    }
    return count;
  }

  /// Total academic (non-break) periods.
  int get academicPeriodCount => periods.where((p) => !p.isBreak).length;

  bool isDayComplete(String day) =>
      academicPeriodCount > 0 && filledCount(day) >= academicPeriodCount;
}

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// PERIOD TEMPLATES
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

class PeriodTemplates {
  static List<PeriodDef> nmims() => [
        PeriodDef(id: 'p1', name: 'Period 1', startMinutes: _m(9, 15), endMinutes: _m(10, 15)),
        PeriodDef(id: 'p2', name: 'Period 2', startMinutes: _m(10, 15), endMinutes: _m(11, 15)),
        PeriodDef(id: 'b1', name: 'Short Break', startMinutes: _m(11, 15), endMinutes: _m(11, 30), kind: PeriodKind.breakTime),
        PeriodDef(id: 'p3', name: 'Period 3', startMinutes: _m(11, 30), endMinutes: _m(12, 30)),
        PeriodDef(id: 'p4', name: 'Period 4', startMinutes: _m(12, 30), endMinutes: _m(13, 30)),
        PeriodDef(id: 'l1', name: 'Lunch', startMinutes: _m(13, 30), endMinutes: _m(14, 15), kind: PeriodKind.lunch),
        PeriodDef(id: 'p5', name: 'Period 5', startMinutes: _m(14, 15), endMinutes: _m(15, 15)),
        PeriodDef(id: 'p6', name: 'Period 6', startMinutes: _m(15, 15), endMinutes: _m(16, 15)),
      ];

  static List<PeriodDef> jntuh() => [
        PeriodDef(id: 'p1', name: 'Period 1', startMinutes: _m(9, 20), endMinutes: _m(10, 10)),
        PeriodDef(id: 'p2', name: 'Period 2', startMinutes: _m(10, 10), endMinutes: _m(11, 0)),
        PeriodDef(id: 'p3', name: 'Period 3', startMinutes: _m(11, 0), endMinutes: _m(11, 50)),
        PeriodDef(id: 'b1', name: 'Break', startMinutes: _m(11, 50), endMinutes: _m(12, 30), kind: PeriodKind.breakTime),
        PeriodDef(id: 'p4', name: 'Period 4', startMinutes: _m(12, 30), endMinutes: _m(13, 20)),
        PeriodDef(id: 'p5', name: 'Period 5', startMinutes: _m(13, 20), endMinutes: _m(14, 10)),
        PeriodDef(id: 'p6', name: 'Period 6', startMinutes: _m(14, 10), endMinutes: _m(15, 0)),
        PeriodDef(id: 'p7', name: 'Period 7', startMinutes: _m(15, 0), endMinutes: _m(15, 50)),
      ];

  static List<PeriodDef> ou() => [
        PeriodDef(id: 'p1', name: 'Period 1', startMinutes: _m(9, 0), endMinutes: _m(9, 50)),
        PeriodDef(id: 'p2', name: 'Period 2', startMinutes: _m(9, 50), endMinutes: _m(10, 40)),
        PeriodDef(id: 'p3', name: 'Period 3', startMinutes: _m(10, 40), endMinutes: _m(11, 30)),
        PeriodDef(id: 'b1', name: 'Break', startMinutes: _m(11, 30), endMinutes: _m(11, 45), kind: PeriodKind.breakTime),
        PeriodDef(id: 'p4', name: 'Period 4', startMinutes: _m(11, 45), endMinutes: _m(12, 35)),
        PeriodDef(id: 'l1', name: 'Lunch', startMinutes: _m(12, 35), endMinutes: _m(13, 20), kind: PeriodKind.lunch),
        PeriodDef(id: 'p5', name: 'Period 5', startMinutes: _m(13, 20), endMinutes: _m(14, 10)),
        PeriodDef(id: 'p6', name: 'Period 6', startMinutes: _m(14, 10), endMinutes: _m(15, 0)),
      ];

  static int _m(int h, int min) => h * 60 + min;
}
