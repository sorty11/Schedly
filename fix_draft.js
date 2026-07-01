const fs = require('fs');
let c = fs.readFileSync('lib/draft_studio_page.dart', 'utf8');

c = c.replace(/return const Scaffold\(body: Center\(child: Text\('No working days configured\.'\)\)\);/, 
`return Scaffold(body: Center(child: FloatingEmptyState(
        icon: Icons.calendar_today_rounded,
        title: 'No Working Days',
        subtitle: 'No working days have been configured for this section.',
      )));`);

if (!c.includes('widgets/animations/floating_empty_state.dart')) {
  c = c.replace(/import 'widgets\/app_dialogs.dart';/, "import 'widgets/app_dialogs.dart';\nimport 'widgets/animations/floating_empty_state.dart';");
}
if (!c.includes('package:flutter/services.dart')) {
  c = c.replace(/import 'package:google_fonts\/google_fonts.dart';/, "import 'package:google_fonts/google_fonts.dart';\nimport 'package:flutter/services.dart';");
}

fs.writeFileSync('lib/draft_studio_page.dart', c);
console.log('Fixed draft_studio_page.dart safely');
