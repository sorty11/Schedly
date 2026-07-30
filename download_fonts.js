const https = require('https');
const fs = require('fs');
const path = require('path');

const fonts = {
  'Inter-Variable.ttf': 'https://raw.githubusercontent.com/google/fonts/main/ofl/inter/Inter%5Bslnt%2Cwght%5D.ttf',
  'Outfit-Variable.ttf': 'https://raw.githubusercontent.com/google/fonts/main/ofl/outfit/Outfit%5Bwght%5D.ttf'
};

const fontDir = path.join(__dirname, 'assets', 'fonts');
if (!fs.existsSync(fontDir)) {
  fs.mkdirSync(fontDir, { recursive: true });
}

async function downloadFonts() {
  for (const [filename, url] of Object.entries(fonts)) {
    const dest = path.join(fontDir, filename);
    console.log(`Downloading ${filename}...`);
    
    await new Promise((resolve, reject) => {
      const file = fs.createWriteStream(dest);
      https.get(url, (response) => {
        if (response.statusCode === 301 || response.statusCode === 302) {
            https.get(response.headers.location, (redirectRes) => {
                redirectRes.pipe(file);
                file.on('finish', () => { file.close(resolve); });
            }).on('error', reject);
        } else {
            response.pipe(file);
            file.on('finish', () => { file.close(resolve); });
        }
      }).on('error', (err) => {
        fs.unlink(dest, () => reject(err));
      });
    });
    console.log(`Saved ${filename}`);
  }
}

downloadFonts().catch(console.error);
