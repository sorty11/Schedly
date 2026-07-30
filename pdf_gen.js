const puppeteer = require('puppeteer-core');
const fs = require('fs');

(async () => {
  try {
    const browser = await puppeteer.launch({
      executablePath: 'C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe',
      headless: 'new'
    });
    const page = await browser.newPage();
    
    // Read the HTML content locally to avoid file protocol weirdness if any
    const htmlContent = fs.readFileSync('C:\\Users\\ACER\\Desktop\\Schedly_Engineering_Report.html', 'utf-8');
    await page.setContent(htmlContent, { waitUntil: 'networkidle0' });
    
    // Or navigate via file://
    // await page.goto('file:///C:/Users/ACER/Desktop/Schedly_Engineering_Report.html', { waitUntil: 'networkidle0' });
    
    // Give Mermaid a second to render
    await new Promise(r => setTimeout(r, 2000));
    
    await page.pdf({ 
      path: 'C:\\Users\\ACER\\Desktop\\Schedly_Engineering_Report.pdf', 
      format: 'A4', 
      printBackground: true,
      margin: {
        top: '20px',
        bottom: '20px'
      }
    });
    
    await browser.close();
    console.log('PDF Generated Successfully!');
  } catch (error) {
    console.error('Error generating PDF:', error);
  }
})();
