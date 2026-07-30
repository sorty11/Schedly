import os
import re

exceptions_import = "import 'package:schedly/exceptions.dart';"

for root, _, files in os.walk('lib'):
    for file in files:
        if file.endswith('.dart'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()

            if 'throw Exception(' in content:
                new_content = content.replace('throw Exception(', 'throw AppException(')
                
                # Check if import needs to be added
                if 'AppException' in new_content and 'exceptions.dart' not in new_content:
                    # add import after the last import
                    lines = new_content.split('\n')
                    last_import = -1
                    for i, line in enumerate(lines):
                        if line.startswith('import '):
                            last_import = i
                    if last_import != -1:
                        lines.insert(last_import + 1, exceptions_import)
                    else:
                        lines.insert(0, exceptions_import)
                    new_content = '\n'.join(lines)
                
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(new_content)
                print('Updated', filepath)
