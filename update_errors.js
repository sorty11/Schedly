const fs = require('fs');
const path = require('path');

const files = [
  'lib/course_details_setup_page.dart',
  'lib/create_announcement_page.dart',
  'lib/draft_studio_page.dart',
  'lib/manual_timetable_studio.dart',
  'lib/pdf_import_preview_page.dart',
  'lib/widgets/timetable_studio_sheet.dart',
  'lib/cr_auth_bottom_sheet.dart',
  'lib/login_page.dart'
];

files.forEach(filePath => {
    if(!fs.existsSync(filePath)) return;
    let content = fs.readFileSync(filePath, 'utf8');
    let original = content;

    // Replace ScaffoldMessenger.of(context).showSnackBar(...) or AppDialogs.showSnackBar(...) 
    // inside catch blocks with AppDialogs.showError
    
    // Pattern 1: AppDialogs.showSnackBar inside catch blocks with e.toString()
    content = content.replace(/AppDialogs\.showSnackBar\(\s*context:\s*context,\s*message:\s*e\.toString\(\)\.replaceAll\('Exception:\s*',\s*''\),?\s*\);/g, 
        "AppDialogs.showError(\n        context: context,\n        title: 'Error',\n        message: e.toString().replaceAll('Exception: ', ''),\n      );");

    content = content.replace(/AppDialogs\.showSnackBar\(\s*context:\s*context,\s*message:\s*e\.toString\(\),?\s*\);/g, 
        "AppDialogs.showError(\n        context: context,\n        title: 'Error',\n        message: e.toString().replaceAll('Exception: ', ''),\n      );");

    // Replace ScaffoldMessenger if they exist
    content = content.replace(/ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\(\s*content:\s*Text\(e\.toString\(\)[^)]*\)\s*\)\s*\);/g,
        "AppDialogs.showError(\n        context: context,\n        title: 'Error',\n        message: e.toString().replaceAll('Exception: ', ''),\n      );");

    if (content !== original) {
        fs.writeFileSync(filePath, content, 'utf8');
        console.log('Updated error dialogs in', filePath);
    }
});
