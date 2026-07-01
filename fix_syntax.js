const fs = require('fs');
const path = require('path');

function walkDir(dir, callback) {
    fs.readdirSync(dir).forEach(f => {
        let dirPath = path.join(dir, f);
        let isDirectory = fs.statSync(dirPath).isDirectory();
        isDirectory ? walkDir(dirPath, callback) : callback(path.join(dir, f));
    });
}

walkDir('./lib', function(filePath) {
    if (!filePath.endsWith('.dart')) return;
    let content = fs.readFileSync(filePath, 'utf8');
    let originalContent = content;

    // Fix .0
    content = content.replace(/(AppSpacing\.[a-zA-Z0-9]+)\.0/g, '$1');
    content = content.replace(/(AppRadius\.[a-zA-Z0-9]+)\.0/g, '$1');

    // Add import if AppSpacing or AppRadius is used but not imported
    if ((content.includes('AppSpacing') || content.includes('AppRadius')) && 
        !content.includes('theme.dart')) {
        content = content.replace(/^(import .*;\n)+/m, (match) => {
            return match + "import 'package:schedly/theme/theme.dart';\n";
        });
    }

    if (content !== originalContent) {
        fs.writeFileSync(filePath, content, 'utf8');
        console.log('Fixed', filePath);
    }
});
