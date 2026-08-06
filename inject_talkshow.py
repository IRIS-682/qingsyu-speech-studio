import json

# Load extracted manuscripts
with open('脱口秀_manuscripts.json', 'r', encoding='utf-8') as f:
    talk_show_ms = json.load(f)

print(f'Loaded {len(talk_show_ms)} talk show manuscripts')

# Build JS array entry for each - use json.dumps for proper escaping
entries = []
for m in talk_show_ms:
    title_escaped = json.dumps(m['title'], ensure_ascii=False)
    content_escaped = json.dumps(m['content'], ensure_ascii=False)
    entry = '{title:' + title_escaped + ',content:' + content_escaped + ",type:'脱口秀宣讲'}"
    entries.append(entry)

new_entries_str = ',\n    ' + ',\n    '.join(entries)

print(f'Generated {len(entries)} JS entries')

with open('青言青语宣讲稿创意写作工坊.html', 'r', encoding='utf-8') as f:
    html = f.read()

ms_start = html.index('let MANUSCRIPTS = [')
print(f'MANUSCRIPTS array starts at char {ms_start}')

# Find end by bracket counting
depth = 0
end_pos = -1
for i in range(ms_start, len(html)):
    ch = html[i]
    if ch == '[':
        depth += 1
    elif ch == ']':
        depth -= 1
        if depth == 0:
            end_pos = i
            break

print(f'MANUSCRIPTS array ends at char {end_pos}')

# Insert new entries before the closing bracket
new_html = html[:end_pos] + new_entries_str + '\n  ' + html[end_pos:]

# Update count references
new_html = new_html.replace('26篇团队稿件', '47篇团队稿件')
new_html = new_html.replace('26篇团队过往', '47篇团队过往')
new_html = new_html.replace('从26篇稿件', '从47篇稿件')

with open('青言青语宣讲稿创意写作工坊.html', 'w', encoding='utf-8') as f:
    f.write(new_html)

print('Done!')

# Verify
ms_count = new_html.count("type:'脱口秀宣讲'")
print(f'脱口秀宣讲 in HTML: {ms_count}')
print(f'47篇 present: {"47篇" in new_html}')
print(f'26篇 present: {"26篇" in new_html}')
