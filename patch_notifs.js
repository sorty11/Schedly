const fs = require('fs');

function patch(file, regex, replacement) {
  let content = fs.readFileSync(file, 'utf8');
  if (!content.includes("import 'services/notification_service.dart';") &&
      !content.includes("import '../services/notification_service.dart';")) {
    // try to import NotificationService
    const importStmt = file.includes('/') ? "import '../services/notification_service.dart';" : "import 'services/notification_service.dart';";
    content = importStmt + '\n' + content;
  }
  content = content.replace(regex, replacement);
  fs.writeFileSync(file, content);
  console.log('Patched ' + file);
}

patch(
  'lib/cr_auth_bottom_sheet.dart', 
  /await prefs\.setString\('selected_division', _sectionId\!\);/g, 
  "await prefs.setString('selected_division', _sectionId!); await NotificationService.updateDivisionSubscription(_sectionId!);");

patch(
  'lib/login_page.dart',
  /await prefs\.setString\('selected_division', sectionId\);/g,
  "await prefs.setString('selected_division', sectionId); await NotificationService.updateDivisionSubscription(sectionId);");

patch(
  'lib/role_verification_page.dart',
  /await prefs\.setString\('selected_division', widget\.division\);/g,
  "await prefs.setString('selected_division', widget.division); await NotificationService.updateDivisionSubscription(widget.division);");
