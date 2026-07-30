import os
import re

base_dir = r"C:\Users\ACER\Desktop\schedly\.antigravity"

all_files = []
for root, _, files in os.walk(base_dir):
    for file in files:
        if file.endswith(".md"):
            all_files.append(os.path.relpath(os.path.join(root, file), base_dir).replace("\\", "/"))

print(f"Found {len(all_files)} files.")

# Regex to find references like `folder/file.md` or `/folder/file.md`
link_pattern = re.compile(r'`/?([a-zA-Z0-9_-]+/[a-zA-Z0-9_-]+\.md)`')

broken_links = []
orphans = set(all_files)
orphans.discard("INDEX.md")
orphans.discard("orchestration.md")

for file in all_files:
    with open(os.path.join(base_dir, file), "r", encoding="utf-8") as f:
        content = f.read()
    
    matches = link_pattern.findall(content)
    for match in matches:
        match_clean = match.lstrip("/")
        if match_clean not in all_files:
            broken_links.append((file, match_clean))
        else:
            if match_clean in orphans:
                orphans.remove(match_clean)

print("Broken Links:")
for source, target in broken_links:
    print(f"  {source} -> {target}")

print("\nOrphan Files (No other file references them):")
for orphan in orphans:
    print(f"  {orphan}")
