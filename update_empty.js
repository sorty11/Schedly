const fs = require('fs');

const data = [
  {
    file: 'lib/course_details_setup_page.dart',
    search: `Center(
              child: Text('No subjects found in timetable.',
                  style: GoogleFonts.inter(color: sem.onSurfaceMuted)))`,
    replace: `Center(
              child: FloatingEmptyState(
                icon: Icons.book_rounded,
                title: 'No Subjects Found',
                message: 'We could not find any subjects in your timetable.',
              ),
            )`,
    import: `import 'widgets/animations/floating_empty_state.dart';\n`
  },
  {
    file: 'lib/draft_studio_page.dart',
    search: `return const Scaffold(body: Center(child: Text('No working days configured.')));`,
    replace: `return const Scaffold(body: Center(child: FloatingEmptyState(
        icon: Icons.calendar_today_rounded,
        title: 'No Working Days',
        message: 'No working days have been configured for this section.',
      )));`,
    import: `import 'widgets/animations/floating_empty_state.dart';\n`
  },
  {
    file: 'lib/role_verification_page.dart',
    search: `child: Center(child: Text('No academic subjects found.')),`,
    replace: `child: Center(
                  child: FloatingEmptyState(
                    icon: Icons.menu_book_rounded,
                    title: 'No Subjects',
                    message: 'No academic subjects found.',
                  ),
                ),`,
    import: `import 'widgets/animations/floating_empty_state.dart';\n`
  },
  {
    file: 'lib/sr_conduct_dashboard.dart',
    search: `const Text('No subjects found.', textAlign: TextAlign.center)`,
    replace: `const FloatingEmptyState(
                        icon: Icons.menu_book_rounded,
                        title: 'No Subjects',
                        message: 'No subjects found.',
                      )`,
    import: `import 'widgets/animations/floating_empty_state.dart';\n`
  }
];

data.forEach(({file, search, replace, import: imp}) => {
  if(!fs.existsSync(file)) return;
  let c = fs.readFileSync(file, 'utf8');
  if(c.includes(search)) {
    c = c.replace(search, replace);
    if(!c.includes('floating_empty_state.dart')) {
      c = c.replace(/^(import .*;\n)+/m, match => match + imp);
    }
    fs.writeFileSync(file, c);
    console.log('Updated', file);
  } else {
    console.log('Search string not found in', file);
  }
});
