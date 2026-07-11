import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'app_settings.dart';
import 'services/notification_service.dart';
import 'services/topic_subscription_service.dart';
import 'services/local_notification_service.dart';
import 'services/diagnostic_logger.dart';
import 'models/timetable_entry.dart';
import 'models/faculty_lecture_context.dart';
import 'models/event_category.dart';

class DebugDiagnosticsPage extends StatefulWidget {
  const DebugDiagnosticsPage({super.key});

  @override
  State<DebugDiagnosticsPage> createState() => _DebugDiagnosticsPageState();
}

class _DebugDiagnosticsPageState extends State<DebugDiagnosticsPage> {
  bool _isLoading = true;
  String _appVersion = 'Loading...';
  String _fcmToken = 'Unknown';
  String _tokenStatus = 'Checking...';
  Map<String, dynamic> _deviceTokenDoc = {};
  List<String> _pendingReminders = [];
  List<String> _executionLogs = [];
  Map<String, bool> _checklist = {
    'Token Generated': false,
    'Token Saved': false,
    'Topics Subscribed': false,
    'Notification Permission': false,
    'Reminder Scheduled': false,
    'Notification Received': false,
    'Notification Opened': false,
    'Deep Link Success': false,
  };

  @override
  void initState() {
    super.initState();
    _loadDiagnostics();
  }

  Future<void> _loadDiagnostics() async {
    setState(() => _isLoading = true);
    try {
      final pkg = await PackageInfo.fromPlatform();
      _appVersion = '${pkg.version} (${pkg.buildNumber})';
      
      if (kIsWeb) {
        _fcmToken = await NotificationService.messaging.getToken(vapidKey: NotificationService.webVapidKey) ?? 'None';
      } else {
        _fcmToken = await NotificationService.messaging.getToken() ?? 'None';
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _fcmToken != 'None') {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('fcm_tokens')
            .doc(_fcmToken)
            .get();
        if (doc.exists) {
          _deviceTokenDoc = doc.data() ?? {};
          _tokenStatus = 'Saved (${_deviceTokenDoc['updatedAt'] != null ? 'Synced' : 'No Timestamp'})';
          _checklist['Token Saved'] = true;
        } else {
          _tokenStatus = 'Not Saved in Firestore';
          _checklist['Token Saved'] = false;
        }
      } else {
        _tokenStatus = 'No User / No Token';
      }

      if (_fcmToken != 'None') {
        _checklist['Token Generated'] = true;
      }

      // Check pending reminders (Local Notifications)
      final pendingList = await LocalNotificationService.notifications.pendingNotificationRequests();
      _pendingReminders = [
        '[Total Pending: ${pendingList.length}]',
        ...pendingList.map((r) => '${r.id}: ${r.title}')
      ];

    } catch (e) {
      debugPrint('Diagnostics Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendTestOutbox(String type, String title, String body, {String? roleTarget}) async {
    try {
      final baseId = 'test_${DateTime.now().millisecondsSinceEpoch}';
      final payload = {
        'notificationId': baseId,
        'type': type,
        'title': title,
        'body': body,
        'division': AppSettings.facultyId ?? AppSettings.sectionId ?? 'unknown',
        'priority': 'high',
        'processed': false,
        'attempts': 0,
        'nextRetryAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'uid': FirebaseAuth.instance.currentUser?.uid ?? '',
      };
      if (roleTarget != null) {
        payload['role'] = roleTarget;
      }
      
      final docRef = FirebaseFirestore.instance.collection('notification_outbox').doc();
      await docRef.set(payload);
      
      setState(() {
        _executionLogs.add('[${DateTime.now().toIso8601String()}] TRIGGER: $type');
        _executionLogs.add('Role: ${roleTarget ?? "unknown"} | Div: ${payload['division']} | UID: ${payload['uid']}');
        _executionLogs.add('Target Topic: ${roleTarget != null ? "role_${roleTarget}_${payload['division']}" : "unknown"}');
        _executionLogs.add('Outbox Doc ID: ${docRef.id}');
        _executionLogs.add('Status: Queued to Outbox Worker');
        _checklist['Notification Permission'] = true; // Assumed for test
      });

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Test $type queued to Outbox')));
    } catch (e) {
      setState(() {
        _executionLogs.add('[ERROR] Failed to queue: $e');
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _exportFCMTrace() async {
    final user = FirebaseAuth.instance.currentUser;
    final buffer = StringBuffer();
    buffer.writeln('=== SCHEDLY FCM TRACE EXPORT ===');
    buffer.writeln('Timestamp: ${DateTime.now().toIso8601String()}');
    buffer.writeln('App Version: $_appVersion');
    buffer.writeln('');
    buffer.writeln('--- IDENTITY ---');
    buffer.writeln('Current Role: ${AppSettings.currentRole.name}');
    buffer.writeln('Immutable Faculty ID: ${AppSettings.facultyId ?? 'N/A'}');
    buffer.writeln('Academic Division(s): ${AppSettings.facultyAssignedDivisions?.join(', ') ?? AppSettings.sectionId ?? 'N/A'}');
    buffer.writeln('Firebase UID: ${user?.uid ?? 'None'}');
    buffer.writeln('');
    buffer.writeln('--- TOKENS & SUBSCRIPTIONS ---');
    buffer.writeln('FCM Token: $_fcmToken');
    buffer.writeln('Token Status: $_tokenStatus');
    buffer.writeln('Firestore Doc: ${_deviceTokenDoc.toString()}');
    // For subscribed topics, we'd need a plugin or internal tracking, but we can dump prefs:
    final prefs = await SharedPreferences.getInstance();
    buffer.writeln('Pref Topic: ${prefs.getString('current_fcm_topic') ?? 'None'}');
    buffer.writeln('Pref Role Topic: ${prefs.getString('current_fcm_role_topic') ?? 'None'}');
    buffer.writeln('Pref Batch Topic: ${prefs.getString('current_fcm_batch_topic') ?? 'None'}');
    buffer.writeln('');
    buffer.writeln('--- PERMISSIONS ---');
    final settings = await NotificationService.messaging.getNotificationSettings();
    buffer.writeln('Android Notification Permission: ${settings.authorizationStatus.name}');
    try {
      final androidPlugin = LocalNotificationService.notifications.resolvePlatformSpecificImplementation<
          // ignore: undefined_class
          AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        final exact = await androidPlugin.canScheduleExactNotifications();
        buffer.writeln('Exact Alarm Permission: ${exact ?? false}');
      }
    } catch (_) {
      buffer.writeln('Exact Alarm Permission: Unknown');
    }
    buffer.writeln('');
    buffer.writeln('--- PENDING REMINDERS ---');
    if (_pendingReminders.isEmpty) {
      buffer.writeln('None');
    } else {
      for (final r in _pendingReminders) {
        buffer.writeln(r);
      }
    }
    buffer.writeln('');
    buffer.writeln('--- LAST 20 NOTIFICATION EVENTS ---');
    if (DiagnosticLogger.fcmLogs.isEmpty) buffer.writeln('None');
    for (final log in DiagnosticLogger.fcmLogs) {
      buffer.writeln(log);
    }
    buffer.writeln('');
    buffer.writeln('--- LAST 20 SESSION TRANSITION EVENTS ---');
    if (DiagnosticLogger.sessionLogs.isEmpty) buffer.writeln('None');
    for (final log in DiagnosticLogger.sessionLogs) {
      buffer.writeln(log);
    }
    buffer.writeln('================================');

    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trace copied to clipboard!')));
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Developer Diagnostics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_rounded),
            tooltip: 'Export FCM Trace',
            onPressed: _exportFCMTrace,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDiagnostics,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader('Identity & Environment'),
          _buildItem('Current Role', AppSettings.currentRole.toString().split('.').last),
          _buildItem('Firebase UID', user?.uid ?? 'None'),
          _buildItem('Immutable Faculty ID', AppSettings.facultyId ?? 'N/A'),
          _buildItem('Current Division', AppSettings.sectionId ?? 'N/A'),
          _buildItem('Assigned Divisions', AppSettings.facultyAssignedDivisions?.join(', ') ?? 'N/A'),
          _buildItem('Current Platform', kIsWeb ? 'Flutter Web' : (defaultTargetPlatform.name)),
          _buildItem('App Version', _appVersion),
          _buildItem('Build Mode', kReleaseMode ? 'RELEASE' : (kProfileMode ? 'PROFILE' : 'DEBUG')),
          
          const Divider(),
          _buildHeader('Notifications Pipeline'),
          _buildItem('FCM Token', _fcmToken),
          _buildItem('Saved Token Status', _tokenStatus),
          _buildItem('Token Routing Div', _deviceTokenDoc['division']?.toString() ?? 'N/A'),
          _buildItem('Token Routing Role', _deviceTokenDoc['role']?.toString() ?? 'N/A'),
          _buildItem('Pending Reminders', _pendingReminders.isEmpty ? 'None' : _pendingReminders.join('\n')),
          
          const Divider(),
          _buildHeader('Test Center Actions (Triggers Outbox Worker)'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton(
                onPressed: () => _sendTestOutbox('test', 'Test Notification', 'This is a test notification'),
                child: const Text('Send Test Notification'),
              ),
              ElevatedButton(
                onPressed: () => _sendTestOutbox('announcement', 'Faculty Announcement', 'Important update for you', roleTarget: 'faculty'),
                child: const Text('Send Faculty Reminder'),
              ),
              ElevatedButton(
                onPressed: () => _sendTestOutbox('announcement', 'CR Update', 'Message for CRs', roleTarget: 'cr'),
                child: const Text('Send CR Notification'),
              ),
              ElevatedButton(
                onPressed: () => _sendTestOutbox('announcement', 'Student Update', 'Message for Students'),
                child: const Text('Send Student Notification'),
              ),
            ],
          ),
          
          const Divider(),
          _buildHeader('Device Actions'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () async {
                  await NotificationService.initialize();
                  _loadDiagnostics();
                },
                child: const Text('Re-register Device'),
              ),
              OutlinedButton(
                onPressed: () async {
                  if (AppSettings.sectionId != null) {
                    await TopicSubscriptionService.updateSubscriptions(AppSettings.sectionId!, AppSettings.currentRole.name);
                  }
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Topics resubscribed')));
                },
                child: const Text('Re-subscribe Topics'),
              ),
              OutlinedButton(
                onPressed: () async {
                  final now = DateTime.now();
                  final testLecture = FacultyLectureContext(
                    division: AppSettings.sectionId ?? 'unknown',
                    entry: TimetableEntry(
                      id: 'test',
                      subject: 'TEST',
                      category: EventCategory.academic,
                      batch: 'Whole Class',
                      startTime: (now.hour * 60) + now.minute + 60, // 1 hour from now
                      endTime: (now.hour * 60) + now.minute + 120, // 2 hours from now
                      durationMinutes: 60,
                      room: '101',
                      facultyId: 'test',
                    ),
                  );
                  await LocalNotificationService.scheduleFacultyReminders([testLecture], 15);
                  _loadDiagnostics();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scheduled Mock Reminder')));
                },
                child: const Text('Mock Reminder (+1h)'),
              ),
            ],
          ),
          
          const Divider(),
          _buildHeader('Notification Test Runner'),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(8),
            ),
            height: 200,
            child: ListView.builder(
              itemCount: _executionLogs.length,
              itemBuilder: (ctx, i) => Text(
                _executionLogs[i],
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Colors.greenAccent),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildHeader('Live Verification Checklist'),
          ..._checklist.entries.map((e) => CheckboxListTile(
            title: Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500)),
            value: e.value,
            onChanged: (val) {
              setState(() {
                _checklist[e.key] = val ?? false;
              });
            },
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Colors.green,
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueAccent)),
    );
  }

  Widget _buildItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600))),
          Expanded(flex: 3, child: SelectableText(value)),
        ],
      ),
    );
  }
}
