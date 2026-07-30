const fs = require('fs');
const readline = require('readline');

async function processLineByLine() {
  const fileStream = fs.createReadStream('C:\\Users\\ACER\\.gemini\\antigravity\\brain\\a7c1f7e9-0fbb-447a-9563-7751e5db55c0\\.system_generated\\logs\\transcript.jsonl');

  const rl = readline.createInterface({
    input: fileStream,
    crlfDelay: Infinity
  });

  let output = '';
  let count = 1;

  for await (const line of rl) {
    if (line.includes('"type":"USER_INPUT"')) {
      try {
        const obj = JSON.parse(line);
        if (obj.type === 'USER_INPUT' && obj.content) {
          // Truncate if too long to save space, but capture the essence
          let content = obj.content.replace(/\n/g, ' ').trim();
          if (content.length > 500) {
            content = content.substring(0, 500) + '...';
          }
          output += `[Step ${obj.step_index}] ${content}\n\n`;
        }
      } catch (e) {}
    }
  }

  fs.writeFileSync('C:\\Users\\ACER\\Desktop\\schedly\\user_history_summary.txt', output);
  console.log('Done extracting history');
}

processLineByLine();
