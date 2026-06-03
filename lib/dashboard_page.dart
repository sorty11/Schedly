import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'division_selection_page.dart';
import 'weekly_timetable_page.dart';
import 'timetable_data.dart';
import 'edit_lecture_page.dart';
import 'app_settings.dart';
import 'cr_login_page.dart';
import 'user_roles.dart';
import 'cr_panel_page.dart';

class DashboardPage extends StatefulWidget {
  final String division;

  const DashboardPage({
    super.key,
    required this.division,
  });

  @override
  State<DashboardPage> createState() =>
      _DashboardPageState();
}

class _DashboardPageState
    extends State<DashboardPage> {
  late List<Map<String, String>>
      todayLectures;

  late String currentDay;

  @override
  void initState() {
    super.initState();

    currentDay = _getCurrentDay();

    final divisionData =
        TimetableData.timetable[
                widget.division] ??
            <String,
                List<
                    Map<String,
                        String>>>{};

    todayLectures =
        List<Map<String, String>>.from(
      divisionData[currentDay] ??
          <Map<String, String>>[],
    );
  }

  Future<void> _changeDivision(
    BuildContext context,
  ) async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.remove(
      'selected_division',
    );

    if (!context.mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const DivisionSelectionPage(),
      ),
    );
  }

  String _getCurrentDay() {
    switch (DateTime.now().weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      default:
        return 'Sunday';
    }
  }

  IconData _getIcon(
    String subject,
  ) {
    switch (
        subject.toLowerCase()) {
      case 'mathematics':
        return Icons.calculate;

      case 'programming':
      case 'oop':
      case 'java':
        return Icons.computer;

      case 'beee':
        return Icons
            .electrical_services;

      case 'physics':
        return Icons.science;

      case 'chemistry':
        return Icons.biotech;

      case 'dbms':
        return Icons.storage;

      case 'lade':
        return Icons.menu_book;

      default:
        return Icons.book;
    }
  }

  bool _canEditLecture(
    Map<String, String> lecture,
  ) {
    if (AppSettings.currentRole ==
        UserRole.cr) {
      return true;
    }

    if (AppSettings.currentRole ==
        UserRole.sr) {
      return lecture['subject'] ==
          AppSettings.srSubject;
    }

    return false;
  }

  Future<void> _editLecture(
    int index,
  ) async {
    final updatedLecture =
        await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditLecturePage(
          lecture:
              todayLectures[index],
        ),
      ),
    );

    if (updatedLecture != null) {
      setState(() {
        todayLectures[index] =
            Map<String, String>.from(
          updatedLecture,
        );
      });
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final nextLecture =
        todayLectures.isNotEmpty
            ? todayLectures.first
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Schedly',
        ),
        centerTitle: true,
        actions: [
          GestureDetector(
            onTap:
                AppSettings.currentRole ==
                        UserRole.cr
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const CRPanelPage(),
                          ),
                        ).then((_) {
                          setState(() {});
                        });
                      }
                    : null,
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 8,
              ),
              child: Text(
                AppSettings.currentRole ==
                        UserRole.cr
                    ? '👑 CR'
                    : AppSettings.currentRole ==
                            UserRole.sr
                        ? '📚 SR'
                        : 'Student',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.logout,
            ),
            onPressed: () =>
                _changeDivision(
              context,
            ),
          ),
        ],
      ),
      body: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment
                  .stretch,
          children: [
            Card(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                child: Column(
                  children: [
                    GestureDetector(
                      onDoubleTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const CRLoginPage(),
                          ),
                        ).then((_) {
                          setState(() {});
                        });
                      },
                      child: Image.asset(
                        'assets/nmims_logo.png',
                        height: 90,
                      ),
                    ),
                    const SizedBox(
                      height: 10,
                    ),
                    const Text(
                      "SVKM's NMIMS",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight:
                            FontWeight
                                .bold,
                      ),
                    ),
                    const SizedBox(
                      height: 6,
                    ),
                    Text(
                      widget.division,
                      style:
                          const TextStyle(
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            ElevatedButton.icon(
              icon: const Icon(
                Icons.calendar_month,
              ),
              label: const Text(
                'View Weekly Timetable',
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        WeeklyTimetablePage(
                      division:
                          widget.division,
                    ),
                  ),
                );
              },
            ),

            const SizedBox(
              height: 16,
            ),

            if (nextLecture != null)
              Card(
                color:
                    Colors.red.shade50,
                child: Padding(
                  padding:
                      const EdgeInsets
                          .all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      const Text(
                        'NEXT LECTURE',
                        style:
                            TextStyle(
                          color:
                              Colors.red,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                      const SizedBox(
                        height: 8,
                      ),
                      Text(
                        nextLecture[
                                'subject'] ??
                            '',
                        style:
                            const TextStyle(
                          fontSize: 22,
                          fontWeight:
                              FontWeight
                                  .bold,
                        ),
                      ),
                      Text(
                        nextLecture[
                                'time'] ??
                            '',
                      ),
                      Text(
                        'Room: ${nextLecture['room'] ?? ''}',
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(
              height: 16,
            ),

            Text(
              "Today is $currentDay",
              style:
                  const TextStyle(
                fontSize: 22,
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            Expanded(
              child:
                  todayLectures
                          .isEmpty
                      ? const Center(
                          child: Text(
                            'No lectures scheduled today',
                          ),
                        )
                      : ListView.builder(
                          itemCount:
                              todayLectures
                                  .length,
                          itemBuilder:
                              (
                            context,
                            index,
                          ) {
                            final lecture =
                                todayLectures[
                                    index];

                            final isCancelled =
                                lecture['cancelled'] ==
                                    'true';

                            return Card(
                              color: isCancelled
                                  ? Colors
                                      .red
                                      .shade100
                                  : null,
                              child:
                                  ListTile(
                                onLongPress:
                                    _canEditLecture(
                                            lecture)
                                        ? () =>
                                            _editLecture(
                                              index,
                                            )
                                        : null,
                                leading:
                                    Icon(
                                  isCancelled
                                      ? Icons
                                          .cancel
                                      : _getIcon(
                                          lecture['subject'] ??
                                              '',
                                        ),
                                ),
                                title:
                                    Text(
                                  lecture['subject'] ??
                                      '',
                                ),
                                subtitle:
                                    Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment
                                          .start,
                                  children: [
                                    Text(
                                      lecture['time'] ??
                                          '',
                                    ),
                                    Text(
                                      'Room: ${lecture['room'] ?? ''}',
                                    ),
                                    if (isCancelled)
                                      const Text(
                                        '❌ CANCELLED',
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}