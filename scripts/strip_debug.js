const fs = require('fs');
const path = require('path');

const DIRECTORIES = ['lib', 'server/src'];
const EXTENSIONS = ['.dart', '.ts', '.js'];

// Temporary debug strings to match
const TARGETS = [
  'QA_TRACE',
  'DEBUG_',
  'FAC_REQ_',
  'REMINDER',
  'TOKEN_MATCH',
  'OUTBOX',
  'FCM_SEND',
  'FS_TRACE',
  'FS_ERROR'
];

// If a line contains any of these, we keep it even if it has a target
const PRESERVE = [
  'error', 'Error', 'ERROR',
  'warn', 'Warn', 'WARN',
  'fail', 'Fail', 'FAIL',
  'exception', 'Exception',
  'startup', 'started', 'stopped',
  'deployment'
];

let filesModified = 0;
let linesRemoved = 0;

function processFile(filePath) {
  const content = fs.readFileSync(filePath, 'utf8');
  const lines = content.split('\n');
  const newLines = [];
  let modified = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    // Check if line is a print/debugPrint/console.log/logger.debug
    const isLogLine = line.match(/(debugPrint|print|console\.log|logger\.(debug|info))\s*\(/);
    
    if (isLogLine) {
      // Check if it contains a target keyword
      const hasTarget = TARGETS.some(t => line.includes(t));
      
      if (hasTarget) {
        // Check if it contains a preserve keyword
        const shouldPreserve = PRESERVE.some(p => line.includes(p));
        
        if (!shouldPreserve) {
          linesRemoved++;
          modified = true;
          // Skip adding this line
          continue; 
        }
      }
    }
    newLines.push(line);
  }

  if (modified) {
    fs.writeFileSync(filePath, newLines.join('\n'));
    filesModified++;
    console.log(`Modified: ${filePath}`);
  }
}

function walkDir(dir) {
  if (!fs.existsSync(dir)) return;
  const list = fs.readdirSync(dir);
  list.forEach(file => {
    const fullPath = path.join(dir, file);
    const stat = fs.statSync(fullPath);
    if (stat && stat.isDirectory()) {
      walkDir(fullPath);
    } else {
      const ext = path.extname(fullPath);
      if (EXTENSIONS.includes(ext)) {
        processFile(fullPath);
      }
    }
  });
}

console.log('--- STARTING DEBUG PURGE ---');
DIRECTORIES.forEach(dir => walkDir(dir));
console.log('--- PURGE COMPLETE ---');
console.log(`Files modified: ${filesModified}`);
console.log(`Temporary logs removed: ${linesRemoved}`);
