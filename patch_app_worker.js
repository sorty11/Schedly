const fs = require('fs');
let code = fs.readFileSync('server/src/app.ts', 'utf8');

const importStatement = "import { OutboxWorker } from './worker/outbox.worker';\n";
if (!code.includes(importStatement)) {
  code = code.replace("import './config/firebase';", "import './config/firebase';\n" + importStatement);
}

const workerInit = `
const worker = new OutboxWorker();
worker.start();

app.listen(PORT, () => {
  logger.info(\`Server is running on port \${PORT}\`);
});
`;
if (!code.includes("worker.start()")) {
  code = code.replace(/app\.listen\(PORT, \(\) => \{[\s\S]*?\}\);/m, workerInit);
}

fs.writeFileSync('server/src/app.ts', code);
console.log('Patched app.ts');
