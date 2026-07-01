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

    // Remove `const` before EdgeInsets when it uses AppSpacing
    content = content.replace(/const\s+(EdgeInsets\.[a-zA-Z]+\([^)]*AppSpacing[^)]*\))/g, '$1');
    content = content.replace(/const\s+(EdgeInsets\.[a-zA-Z]+\([^)]*AppRadius[^)]*\))/g, '$1');

    // Remove `const` before BorderRadius when it uses AppRadius
    content = content.replace(/const\s+(BorderRadius\.[a-zA-Z]+\([^)]*AppRadius[^)]*\))/g, '$1');
    
    // Add import if AppSpacing or AppRadius is used but not imported
    if ((content.includes('AppSpacing') || content.includes('AppRadius')) && 
        !content.includes('theme/theme.dart')) {
        content = content.replace(/^(import .*;\n)+/m, (match) => {
            return match + "import 'package:schedly/theme/theme.dart';\n";
        });
    }

    if (content !== originalContent) {
        fs.writeFileSync(filePath, content, 'utf8');
        console.log('Fixed', filePath);
    }
});
