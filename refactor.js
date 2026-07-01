const fs = require('fs');
const path = require('path');

const spacingMap = {
    '4': 'AppSpacing.xs',
    '8': 'AppSpacing.sm',
    '12': 'AppSpacing.md',
    '16': 'AppSpacing.lg',
    '20': 'AppSpacing.xl',
    '24': 'AppSpacing.x2l',
    '32': 'AppSpacing.x3l',
    '40': 'AppSpacing.x4l',
    '48': 'AppSpacing.x5l',
    '64': 'AppSpacing.x6l'
};

const radiusMap = {
    '8': 'AppRadius.sm',
    '12': 'AppRadius.md',
    '16': 'AppRadius.lg',
    '20': 'AppRadius.xl', // Let's map 20 to xl because some places use 20. Wait, AppRadius.xl is 24 in theme.dart. I will map 24 to xl.
    '24': 'AppRadius.xl',
    '32': 'AppRadius.x2l'
};

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

    // Replace EdgeInsets numbers
    content = content.replace(/EdgeInsets\.[a-zA-Z]+\([^)]+\)/g, (match) => {
        return match.replace(/\b(\d+)\b/g, (numMatch) => {
            if (spacingMap[numMatch]) return spacingMap[numMatch];
            // If it's a double like 16.0, we can match that too, but let's handle integers first.
            return numMatch;
        }).replace(/\b(\d+)\.0\b/g, (numMatch, p1) => {
            if (spacingMap[p1]) return spacingMap[p1];
            return numMatch;
        });
    });

    // Replace BorderRadius circular
    content = content.replace(/Radius\.circular\(\s*(\d+)(?:\.0)?\s*\)/g, (match, p1) => {
        if (radiusMap[p1]) return `Radius.circular(${radiusMap[p1]})`;
        return match;
    });

    // Also for BorderRadius.all(Radius.circular(...)) which is handled by the above.

    // If changed, add import
    if (content !== originalContent) {
        if (!content.includes("import 'package:schedly/theme/theme.dart';") && 
            !content.includes("import 'theme/theme.dart';") &&
            !content.includes("import '../theme/theme.dart';") &&
            !content.includes("import '../../theme/theme.dart';")) {
            
            // Add import after the first import block
            content = content.replace(/^(import .*;\n)+/m, (match) => {
                return match + "import 'package:schedly/theme/theme.dart';\n";
            });
        }
        fs.writeFileSync(filePath, content, 'utf8');
        console.log('Updated', filePath);
    }
});
