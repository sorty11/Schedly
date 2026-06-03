import 'package:flutter/material.dart';

import 'dashboard_page.dart';
import 'weekly_timetable_page.dart';
import 'profile_page.dart';
import 'announcements_page.dart';

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

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(
        division: widget.division,
      ),

      WeeklyTimetablePage(
        division: widget.division,
      ),

      const AnnouncementsPage(),

      ProfilePage(
        division: widget.division,
      ),
    ];

    return Scaffold(
      body: pages[currentIndex],

      bottomNavigationBar:
          BottomNavigationBar(
        currentIndex: currentIndex,

        onTap: (index) {
          setState(() {
            currentIndex = index;
          });
        },

        type:
            BottomNavigationBarType.fixed,

        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: "Home",
          ),

          BottomNavigationBarItem(
            icon: Icon(
              Icons.calendar_month,
            ),
            label: "Timetable",
          ),

          BottomNavigationBarItem(
            icon: Icon(
              Icons.notifications,
            ),
            label: "Updates",
          ),

          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: "Profile",
          ),
        ],
      ),
    );
  }
}