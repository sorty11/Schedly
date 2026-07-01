const fs = require('fs');

function replaceFileContent(file, replacer) {
  if (fs.existsSync(file)) {
    let content = fs.readFileSync(file, 'utf8');
    let newContent = replacer(content);
    if (content !== newContent) {
      fs.writeFileSync(file, newContent, 'utf8');
      console.log('Fixed', file);
    }
  }
}

// 1. message -> subtitle for FloatingEmptyState
const filesToFixMessage = [
  'lib/course_details_setup_page.dart',
  'lib/draft_studio_page.dart',
  'lib/role_verification_page.dart',
  'lib/sr_conduct_dashboard.dart'
];
filesToFixMessage.forEach(file => {
  replaceFileContent(file, c => c.replace(/message:\s*'We could not find any subjects in your timetable.'/, "subtitle: 'We could not find any subjects in your timetable.'"));
  replaceFileContent(file, c => c.replace(/message:\s*'No working days have been configured for this section.'/, "subtitle: 'No working days have been configured for this section.'"));
  replaceFileContent(file, c => c.replace(/message:\s*'No academic subjects found.'/, "subtitle: 'No academic subjects found.'"));
  replaceFileContent(file, c => c.replace(/message:\s*'No subjects found.'/, "subtitle: 'No subjects found.'"));
});

// 2. Remove const from Scaffold in draft_studio_page.dart
replaceFileContent('lib/draft_studio_page.dart', c => c.replace(/return const Scaffold\(body: Center\(child: FloatingEmptyState/g, "return Scaffold(body: Center(child: FloatingEmptyState"));

// 3. Add flutter/services.dart import to cr_auth_bottom_sheet.dart and login_page.dart
const filesToFixHaptics = [
  'lib/cr_auth_bottom_sheet.dart',
  'lib/login_page.dart'
];
filesToFixHaptics.forEach(file => {
  replaceFileContent(file, c => {
    if (!c.includes('package:flutter/services.dart')) {
      return c.replace(/^(import .*;\n)+/m, match => match + "import 'package:flutter/services.dart';\n");
    }
    return c;
  });
});

// 4. expected_token in animated_card.dart
replaceFileContent('lib/widgets/animations/animated_card.dart', c => {
  return c; // We'll fix animated_card.dart manually next
});
