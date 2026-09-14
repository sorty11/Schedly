import assert from 'node:assert';

console.log('--- Running Assignment Worker & Deadline System Backend Unit Tests ---');

// 1. Deterministic Reminder IDs
function getReminderId(assignmentId, window) {
  return `assignment_${assignmentId}_${window}`;
}

const assignmentId = 'asgn_test_456';
assert.strictEqual(getReminderId(assignmentId, '24h'), 'assignment_asgn_test_456_24h');
assert.strictEqual(getReminderId(assignmentId, '6h'), 'assignment_asgn_test_456_6h');
assert.strictEqual(getReminderId(assignmentId, '1h'), 'assignment_asgn_test_456_1h');
console.log('✓ Deterministic Reminder IDs: PASS');

// 2. Reminder Window Scheduling Filter
function calculateEligibleWindows(nowMs, dueAtMs) {
  const windows = {
    '24h': 24 * 60 * 60 * 1000,
    '6h': 6 * 60 * 60 * 1000,
    '1h': 1 * 60 * 60 * 1000,
  };
  const eligible = [];
  for (const [win, dur] of Object.entries(windows)) {
    const reminderTimeMs = dueAtMs - dur;
    if (reminderTimeMs > nowMs) {
      eligible.push(win);
    }
  }
  return eligible;
}

const now = Date.now();
// 30 hours in future -> all 3
const win30h = calculateEligibleWindows(now, now + (30 * 3600 * 1000));
assert.deepStrictEqual(win30h, ['24h', '6h', '1h']);
console.log('✓ 30h deadline schedules [24h, 6h, 1h]: PASS');

// 10 hours in future -> 6h, 1h (24h passed)
const win10h = calculateEligibleWindows(now, now + (10 * 3600 * 1000));
assert.deepStrictEqual(win10h, ['6h', '1h']);
console.log('✓ 10h deadline schedules [6h, 1h]: PASS');

// 2 hours in future -> 1h (24h and 6h passed)
const win2h = calculateEligibleWindows(now, now + (2 * 3600 * 1000));
assert.deepStrictEqual(win2h, ['1h']);
console.log('✓ 2h deadline schedules [1h]: PASS');

// 30 mins in future -> none
const win30m = calculateEligibleWindows(now, now + (30 * 60 * 1000));
assert.deepStrictEqual(win30m, []);
console.log('✓ 30m deadline schedules []: PASS');

// 3. Deadline Modification Check (Superseding)
function isReminderSuperseded(docDueAtMs, currentAssignmentDueAtMs) {
  return docDueAtMs !== currentAssignmentDueAtMs;
}

assert.strictEqual(isReminderSuperseded(1700000000000, 1700000000000), false);
assert.strictEqual(isReminderSuperseded(1700000000000, 1700003600000), true);
console.log('✓ Deadline modification detection: PASS');

// 4. Assignment Cancellation Check
function shouldProcessReminder(assignmentStatus) {
  return assignmentStatus === 'active';
}

assert.strictEqual(shouldProcessReminder('active'), true);
assert.strictEqual(shouldProcessReminder('cancelled'), false);
assert.strictEqual(shouldProcessReminder('deleted'), false);
console.log('✓ Assignment status check: PASS');

// 5. Student Eligibility Filtering
function isStudentEligible({
  targetBatch,
  studentBatch,
  hasSubmitted,
  window,
  studentPreferences,
}) {
  // Batch check
  if (targetBatch && targetBatch !== 'Whole Class' && studentBatch !== targetBatch) {
    return false;
  }
  // Submission check
  if (hasSubmitted) {
    return false;
  }
  // Preference check
  if (studentPreferences && window && studentPreferences[window] === false) {
    return false;
  }
  return true;
}

// Student 1: unsubmitted, matching batch, prefs true -> ELIGIBLE
assert.strictEqual(
  isStudentEligible({
    targetBatch: 'C1',
    studentBatch: 'C1',
    hasSubmitted: false,
    window: '24h',
    studentPreferences: { '24h': true, '6h': true, '1h': true },
  }),
  true
);

// Student 2: already submitted -> INELIGIBLE
assert.strictEqual(
  isStudentEligible({
    targetBatch: 'C1',
    studentBatch: 'C1',
    hasSubmitted: true,
    window: '24h',
    studentPreferences: { '24h': true },
  }),
  false
);

// Student 3: opted out of 24h reminder -> INELIGIBLE for 24h
assert.strictEqual(
  isStudentEligible({
    targetBatch: 'C1',
    studentBatch: 'C1',
    hasSubmitted: false,
    window: '24h',
    studentPreferences: { '24h': false, '6h': true, '1h': true },
  }),
  false
);

// Student 3: eligible for 6h reminder
assert.strictEqual(
  isStudentEligible({
    targetBatch: 'C1',
    studentBatch: 'C1',
    hasSubmitted: false,
    window: '6h',
    studentPreferences: { '24h': false, '6h': true, '1h': true },
  }),
  true
);

// Student 4: different batch (C2) -> INELIGIBLE for C1 assignment
assert.strictEqual(
  isStudentEligible({
    targetBatch: 'C1',
    studentBatch: 'C2',
    hasSubmitted: false,
    window: '24h',
    studentPreferences: {},
  }),
  false
);

// Student 5: Whole Class assignment -> ELIGIBLE regardless of student batch
assert.strictEqual(
  isStudentEligible({
    targetBatch: 'Whole Class',
    studentBatch: 'C2',
    hasSubmitted: false,
    window: '24h',
    studentPreferences: {},
  }),
  true
);

console.log('✓ Student eligibility, submission, and preference filtering: PASS');

// 6. Timezone Math
const utcTimestamp1 = new Date('2026-09-20T23:00:00.000Z').getTime();
const utcTimestamp2 = new Date('2026-09-20T23:00:00.000+05:30').getTime();
assert.strictEqual(utcTimestamp1 - utcTimestamp2, 5.5 * 3600 * 1000);
console.log('✓ Absolute UTC Timestamp equivalence and arithmetic: PASS');

console.log('--- All Backend Assignment System Tests Passed Successfully ---');
