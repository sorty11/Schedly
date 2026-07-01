const fs = require('fs');

const files = [
  'lib/manual_timetable_studio.dart',
  'lib/widgets/studio/batch_setup_step.dart',
  'lib/widgets/studio/weekly_builder_step.dart'
];

files.forEach(file => {
  if (fs.existsSync(file)) {
    let content = fs.readFileSync(file, 'utf8');
    let newContent = content.split('\n').filter(line => !line.includes("print('DEBUG")).join('\n');
    if (content !== newContent) {
      fs.writeFileSync(file, newContent, 'utf8');
      console.log('Removed print statements from', file);
    }
  }
});
