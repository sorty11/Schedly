const fs = require('fs');
const path = require('path');

const markdownPath = 'C:\\Users\\ACER\\.gemini\\antigravity\\brain\\a7c1f7e9-0fbb-447a-9563-7751e5db55c0\\artifacts\\schedly_engineering_report.md';
const outputPath = 'C:\\Users\\ACER\\Desktop\\Schedly_Engineering_Report.html';

const markdownContent = fs.readFileSync(markdownPath, 'utf-8');

const htmlTemplate = `<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Schedly Engineering Report</title>
    <!-- Fonts -->
    <link rel="preconnect" href="https://fonts.googleapis.com">
    <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=Fira+Code:wght@400;500&display=swap" rel="stylesheet">
    <!-- Markdown CSS -->
    <style>
        :root {
            --bg: #ffffff;
            --text: #1d1d1f;
            --muted: #86868b;
            --border: #d2d2d7;
            --accent: #007aff;
            --surface: #f5f5f7;
            --success: #34c759;
            --warning: #ff9500;
            --danger: #ff3b30;
        }
        body {
            font-family: 'Inter', -apple-system, BlinkMacSystemFont, sans-serif;
            color: var(--text);
            background-color: var(--bg);
            line-height: 1.6;
            margin: 0;
            padding: 0;
            -webkit-font-smoothing: antialiased;
        }
        .container {
            max-width: 900px;
            margin: 0 auto;
            padding: 80px 40px;
        }
        h1, h2, h3, h4 {
            font-weight: 600;
            letter-spacing: -0.02em;
            margin-top: 2em;
            margin-bottom: 0.5em;
            color: #000;
        }
        h1 { font-size: 2.8rem; text-align: center; margin-top: 0; margin-bottom: 0.2em;}
        h2 { font-size: 2rem; border-bottom: 1px solid var(--border); padding-bottom: 0.3em; margin-top: 2.5em; }
        h3 { font-size: 1.5rem; margin-top: 2em;}
        p { margin-bottom: 1.2em; font-size: 1.1rem; color: #333;}
        .subtitle {
            text-align: center;
            font-size: 1.25rem;
            color: var(--muted);
            margin-bottom: 4rem;
            font-weight: 400;
        }
        a {
            color: var(--accent);
            text-decoration: none;
        }
        a:hover {
            text-decoration: underline;
        }
        .hero-icon {
            display: flex;
            align-items: center;
            justify-content: center;
            margin: 0 auto 2rem;
            width: 100px;
            height: 100px;
            border-radius: 22px;
            background: linear-gradient(135deg, #007aff, #34c759);
            box-shadow: 0 10px 30px rgba(0, 122, 255, 0.3);
            color: white;
            font-size: 48px;
            font-weight: bold;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin: 2em 0;
            font-size: 1.05rem;
        }
        th, td {
            text-align: left;
            padding: 16px;
            border-bottom: 1px solid var(--border);
        }
        th {
            background-color: var(--surface);
            font-weight: 600;
            color: #000;
        }
        table {
            border: 1px solid var(--border);
            border-radius: 12px;
            overflow: hidden;
            box-shadow: 0 4px 6px rgba(0,0,0,0.02);
        }
        tr:last-child td { border-bottom: none; }
        blockquote {
            margin: 2em 0;
            padding: 24px 32px;
            background-color: var(--surface);
            border-left: 4px solid var(--accent);
            border-radius: 0 12px 12px 0;
            font-size: 1.15rem;
            font-style: italic;
            color: #444;
        }
        blockquote p { margin: 0; }
        .callout-important {
            background-color: #fff0f0;
            border: 1px solid #ffd6d6;
            border-left: 4px solid var(--danger);
            padding: 24px;
            border-radius: 12px;
            margin: 2em 0;
        }
        .callout-note {
            background-color: #f0f8ff;
            border: 1px solid #cce5ff;
            border-left: 4px solid var(--accent);
            padding: 24px;
            border-radius: 12px;
            margin: 2em 0;
        }
        .callout-tip {
            background-color: #f0fff4;
            border: 1px solid #c6f6d5;
            border-left: 4px solid var(--success);
            padding: 24px;
            border-radius: 12px;
            margin: 2em 0;
        }
        pre {
            background-color: var(--surface);
            padding: 24px;
            border-radius: 12px;
            overflow-x: auto;
            font-family: 'Fira Code', monospace;
            font-size: 0.95rem;
            border: 1px solid var(--border);
            line-height: 1.5;
        }
        code {
            font-family: 'Fira Code', monospace;
            background-color: var(--surface);
            padding: 2px 6px;
            border-radius: 4px;
            font-size: 0.9em;
            color: var(--danger);
        }
        pre code { background: none; padding: 0; color: inherit; }
        .mermaid {
            background: white;
            padding: 32px;
            border-radius: 12px;
            border: 1px solid var(--border);
            margin: 2em 0;
            box-shadow: 0 4px 12px rgba(0,0,0,0.03);
            display: flex;
            justify-content: center;
        }
        .progress-row {
            display: flex;
            align-items: center;
            margin-bottom: 12px;
            font-family: 'Fira Code', monospace;
            font-size: 0.95rem;
        }
        .progress-label {
            width: 220px;
        }
        .progress-track {
            flex: 1;
            height: 10px;
            background-color: var(--border);
            border-radius: 5px;
            margin-right: 16px;
            overflow: hidden;
        }
        .progress-fill {
            height: 100%;
            background: linear-gradient(90deg, #007aff, #34c759);
            border-radius: 5px;
            width: 100%;
        }
        hr {
            border: none;
            height: 1px;
            background-color: var(--border);
            margin: 4em 0;
        }
        ul, ol {
            padding-left: 24px;
            font-size: 1.1rem;
        }
        li {
            margin-bottom: 8px;
        }
        
        /* Utility for Apple-like center text */
        .text-center { text-align: center; }
        .hero-section { text-align: center; margin-bottom: 4rem; }
    </style>
</head>
<body>
    <div class="container" id="content">
        <!-- Markdown injected here via JS -->
    </div>
    
    <script type="text/markdown" id="raw-markdown">
${markdownContent}
    </script>

    <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/mermaid/dist/mermaid.min.js"></script>
    <script>
        mermaid.initialize({ startOnLoad: false, theme: 'neutral', fontFamily: 'Inter' });
        
        const rawMarkdown = document.getElementById('raw-markdown').textContent;
        
        // Custom renderer for marked
        const renderer = new marked.Renderer();
        
        // Handle custom callouts
        const originalBlockquote = renderer.blockquote.bind(renderer);
        renderer.blockquote = function(quote) {
            if (quote.includes('[!NOTE]')) {
                return '<div class="callout-note"><strong>📝 Note</strong><br>' + quote.replace(/\\[!NOTE\\]|<br>/g, '') + '</div>';
            }
            if (quote.includes('[!IMPORTANT]')) {
                return '<div class="callout-important"><strong>🚨 Important</strong><br>' + quote.replace(/\\[!IMPORTANT\\]|<br>/g, '') + '</div>';
            }
            if (quote.includes('[!TIP]')) {
                return '<div class="callout-tip"><strong>💡 Tip</strong><br>' + quote.replace(/\\[!TIP\\]|<br>/g, '') + '</div>';
            }
            return originalBlockquote(quote);
        };
        
        // Handle code blocks for Mermaid
        const originalCode = renderer.code.bind(renderer);
        renderer.code = function(code, language, isEscaped) {
            if (language === 'mermaid') {
                return '<div class="mermaid">' + code + '</div>';
            }
            return originalCode(code, language, isEscaped);
        };

        // Render markdown
        marked.setOptions({ renderer: renderer });
        let html = marked.parse(rawMarkdown);
        
        // Fix up the progress bars
        html = html.replace(/\\\`([A-Za-z\\/ ]+):\\\` \\\[(████████████████████)\\\] ([0-9\\+]+)/g, 
            '<div class="progress-row"><div class="progress-label">$1</div><div class="progress-track"><div class="progress-fill"></div></div><div>$3</div></div>');
            
        // Fix the hero section
        html = html.replace('<div align="center">', '<div class="hero-section"><div class="hero-icon">S</div>');
        
        document.getElementById('content').innerHTML = html;
        
        // Render Mermaid
        setTimeout(() => {
            mermaid.run();
        }, 100);
    </script>
</body>
</html>`;

fs.writeFileSync(outputPath, htmlTemplate);
console.log('HTML Report generated successfully at ' + outputPath);
