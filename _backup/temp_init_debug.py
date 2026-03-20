import re, pathlib
path = pathlib.Path('obby-cyber-truck-main.rbxlx')
text = path.read_text(encoding='utf-8', errors='ignore')
pattern = re.compile(r'<string name="Name">Initialize</string>.*?<ProtectedString name="Source"><!\[CDATA\[(.*?)\]\]>', re.S)
matches = list(pattern.finditer(text))
print('matches', len(matches))
for idx, m in enumerate(matches, start=1):
    snippet = m.group(1)
    lines = snippet.splitlines()
    print('match', idx, 'lines', len(lines), 'start with:')
    for i, line in enumerate(lines[:40], start=1):
        print(f'{i:03d}: {line}')
    print('---')
    if idx >= 2:
        break
