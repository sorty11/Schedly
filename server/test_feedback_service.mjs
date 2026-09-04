import assert from 'node:assert';
import { FeedbackEmailService } from './dist/services/feedback.service.js';

console.log('--- Running Feedback Email Service Unit Tests ---');

// Test 1: Subject formatting
const bugSubject = FeedbackEmailService.formatSubject('bug', 'Login notification issue');
assert.strictEqual(bugSubject, '[Schedly Bug] Login notification issue');
console.log('✓ Bug subject formatting: PASS');

const featureSubject = FeedbackEmailService.formatSubject('feature', 'Add dark mode');
assert.strictEqual(featureSubject, '[Schedly Feature] Add dark mode');
console.log('✓ Feature subject formatting: PASS');

const otherSubject = FeedbackEmailService.formatSubject('other', 'Great app experience');
assert.strictEqual(otherSubject, '[Schedly Feedback] Great app experience');
console.log('✓ Other/general subject formatting: PASS');

// Test 2: HTML body contains all required metadata
const sampleData = {
  id: 'fb_test_12345',
  type: 'bug',
  title: 'Test bug title',
  description: 'Line 1\nLine 2',
  email: 'student@example.com',
  name: 'John Doe',
  role: 'Student',
  section: 'SecondYear_CE_C',
  platform: 'Android',
  device: 'Pixel 7',
  appVersion: '1.0.11+11',
  timestamp: '2026-09-04T17:00:00Z',
  uid: 'usr_xyz789',
};

const html = FeedbackEmailService.formatHtmlBody(sampleData);

assert(html.includes('Bug Report 🐞'), 'Missing bug label in HTML');
assert(html.includes('Test bug title'), 'Missing title in HTML');
assert(html.includes('student@example.com'), 'Missing reporter email in HTML');
assert(html.includes('John Doe'), 'Missing reporter name in HTML');
assert(html.includes('Student'), 'Missing role in HTML');
assert(html.includes('SecondYear_CE_C'), 'Missing section in HTML');
assert(html.includes('Android'), 'Missing platform in HTML');
assert(html.includes('Pixel 7'), 'Missing device in HTML');
assert(html.includes('1.0.11+11'), 'Missing appVersion in HTML');
assert(html.includes('usr_xyz789'), 'Missing UID in HTML');
assert(html.includes('fb_test_12345'), 'Missing Report ID in HTML');

console.log('✓ HTML body context validation: PASS');

// Test 3: SMTP configuration probe
const isSmtpConfigured = FeedbackEmailService.isSmtpConfigured();
console.log(`✓ SMTP configuration detected locally: ${isSmtpConfigured ? 'YES' : 'NO'}`);

console.log('--- All Feedback Service Tests Passed Successfully ---');
