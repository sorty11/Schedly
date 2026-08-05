const fs = require('fs');
const path = require('path');
const dir = 'C:/Users/ACER/Desktop/schedly/lib';
function walk(dir) {
  let results = [];
  const list = fs.readdirSync(dir);
  list.forEach(file => {
    file = path.join(dir, file);
    const stat = fs.statSync(file);
    if (stat && stat.isDirectory()) {
      results = results.concat(walk(file));
    } else if(file.endsWith('.dart')) {
      results.push(file);
    }
  });
  return results;
}
const files = walk(dir);
let report = '';
files.forEach(f => {
  const content = fs.readFileSync(f, 'utf8');
  const lines = content.split('\n');
  for(let i=0; i<lines.length; i++) {
    const l = lines[i];
    if(l.includes('FirebaseFirestore.instance') || l.includes('.collection(') || l.includes('.doc(') || l.includes('.delete()') || l.includes('.set(') || l.includes('.update(') || l.includes('runTransaction(') || l.includes('batch()')) {
      report += f + ':' + (i+1) + ': ' + l.trim() + '\n';
    }
  }
});
fs.writeFileSync('firestore_calls.txt', report);
