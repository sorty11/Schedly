const fs = require('fs');
let c = fs.readFileSync('lib/delete_lecture_page.dart', 'utf8');

// 1. Add floating empty state import
if (!c.includes("import 'widgets/animations/floating_empty_state.dart';")) {
  c = c.replace(/import 'widgets\/app_dialogs.dart';/, "import 'widgets/app_dialogs.dart';\nimport 'widgets/animations/floating_empty_state.dart';");
}

// 2. Add variables for stream and isDeleting
c = c.replace(/String\? division;/, "String? division;\n  Stream<QuerySnapshot>? _lecturesStream;\n  bool _isDeleting = false;");

// 3. Update stream when division loads
c = c.replace(/division =[\s\n]*prefs\.getString\([\s\n]*'selected_division',[\s\n]*\);[\s\n]*setState\(\(\) \{\}\);/, 
`division = prefs.getString('selected_division');
    if (division != null) {
      _updateStream();
    }
    setState(() {});`);

// 4. Add _updateStream method
c = c.replace(/Future\<void\> \_deleteLecture/, 
`void _updateStream() {
    if (division == null) return;
    _lecturesStream = FirebaseFirestore.instance
        .collection('timetables')
        .doc(division)
        .collection(selectedDay)
        .snapshots();
  }

  Future<void> _deleteLecture`);

// 5. Update selectedDay change handler
c = c.replace(/setState\(\(\{\) \{\s*selectedDay = value;\s*\}\);/,
`setState(() {
                      selectedDay = value;
                      _updateStream();
                    });`);

// 6. Fix StreamBuilder
c = c.replace(/stream: FirebaseFirestore[\s\n]*\.instance[\s\n]*\.collection\([\s\n]*'timetables',[\s\n]*\)[\s\n]*\.doc\(division\)[\s\n]*\.collection\([\s\n]*selectedDay,[\s\n]*\)[\s\n]*\.snapshots\(\),/m,
`stream: _lecturesStream,`);

// 7. Fix empty state
c = c.replace(/return const Center\([\s\n]*child: Text\([\s\n]*'No lectures found',[\s\n]*\),[\s\n]*\);/m,
`return const Center(
                      child: FloatingEmptyState(
                        icon: Icons.event_busy_rounded,
                        title: 'No Lectures',
                        subtitle: 'No lectures scheduled for this day.',
                      ),
                    );`);

// 8. Fix dialog stacking
c = c.replace(/final shouldDelete = await AppDialogs\.showConfirm\(/,
`if (_isDeleting) return;
    setState(() => _isDeleting = true);
    
    final shouldDelete = await AppDialogs.showConfirm(`);

c = c.replace(/if \(\!shouldDelete \|\|[\s\n]*division \=\= null\) \{[\s\n]*return;[\s\n]*\}/m,
`if (!shouldDelete || division == null) {
      setState(() => _isDeleting = false);
      return;
    }`);

c = c.replace(/AppDialogs\.showError\([\s\S]*?\}\n  \}/m, 
`AppDialogs.showError(
        context: context,
        title: 'Delete Failed',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }`);

fs.writeFileSync('lib/delete_lecture_page.dart', c);
console.log('Fixed delete_lecture_page.dart');
