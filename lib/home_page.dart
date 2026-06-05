import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dashboard_page.dart';
import 'weekly_timetable_page.dart';
import 'updates_page.dart';
import 'profile_page.dart';

class HomePage extends StatefulWidget {
  final String division;

  const HomePage({
    super.key,
    required this.division,
  });

  @override
  State<HomePage> createState() =>
      _HomePageState();
}

class _HomePageState
    extends State<HomePage> {
  int currentIndex = 0;
  int unreadCount = 0;

  @override
  void initState() {
    super.initState();

    _loadUnreadCount();

    FirebaseFirestore.instance
        .collection('notifications')
        .where(
          'division',
          isEqualTo: widget.division,
        )
        .snapshots()
        .listen((_) {
      _loadUnreadCount();
    });
  }

  Future<void> _loadUnreadCount() async {
    try {
      final prefs =
          await SharedPreferences.getInstance();

      final lastSeenMillis =
          prefs.getInt(
                'last_seen_notifications',
              ) ??
              0;

      final snapshot =
          await FirebaseFirestore.instance
              .collection(
                'notifications',
              )
              .where(
                'division',
                isEqualTo:
                    widget.division,
              )
              .get();

      int count = 0;

      for (final doc
          in snapshot.docs) {
        final data = doc.data();

        final timestamp =
            data['createdAt'];

        if (timestamp != null) {
          final createdAt =
              (timestamp
                      as Timestamp)
                  .millisecondsSinceEpoch;

          if (createdAt >
              lastSeenMillis) {
            count++;
          }
        }
      }

      if (!mounted) return;

      setState(() {
        unreadCount = count;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        unreadCount = 0;
      });
    }
  }

  Future<void>
      _markNotificationsRead() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setInt(
      'last_seen_notifications',
      DateTime.now()
          .millisecondsSinceEpoch,
    );

    if (!mounted) return;

    setState(() {
      unreadCount = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        division: widget.division,
      ),

      WeeklyTimetablePage(
        division: widget.division,
      ),

      const UpdatesPage(),

      ProfilePage(
        division: widget.division,
      ),
    ];

    return Scaffold(
      body: pages[currentIndex],

      bottomNavigationBar:
          BottomNavigationBar(
        currentIndex:
            currentIndex,

        onTap: (index) async {
          if (index == 2) {
            await _markNotificationsRead();
          }

          setState(() {
            currentIndex =
                index;
          });
        },

        type:
            BottomNavigationBarType
                .fixed,

        items: [
          const BottomNavigationBarItem(
            icon:
                Icon(Icons.home),
            label: 'Home',
          ),

          const BottomNavigationBarItem(
            icon: Icon(
              Icons.calendar_month,
            ),
            label: 'Timetable',
          ),

          BottomNavigationBarItem(
            icon: const Icon(
              Icons.notifications,
            ),
            label:
                unreadCount > 0
                    ? 'Updates ($unreadCount)'
                    : 'Updates',
          ),

          const BottomNavigationBarItem(
            icon:
                Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

