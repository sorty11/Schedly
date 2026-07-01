const fs = require('fs');
let c = fs.readFileSync('lib/upload_timetable_pdf_page.dart', 'utf8');

c = c.replace(/child: GestureDetector\(/,
`child: Semantics(
                button: true,
                label: 'Upload Timetable PDF',
                child: GestureDetector(`);

c = c.replace(/color: Theme.of\(context\)\.textTheme\.bodyMedium\?\.color\?\.withValues\(alpha: 0\.4\)\)\),\s*\]\s*\),\s*\)\s*\)\s*\);/,
`color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.4))),
                            ]
                          ),
                  ),
                ),
              ),`);

fs.writeFileSync('lib/upload_timetable_pdf_page.dart', c);
console.log('Fixed upload_timetable_pdf_page.dart');
