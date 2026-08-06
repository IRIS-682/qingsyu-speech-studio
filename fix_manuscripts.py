import json, re

with open('脱口秀_manuscripts.json', 'r', encoding='utf-8') as f:
    talk_show_ms = json.load(f)

with open('青言青语宣讲稿创意写作工坊.html', 'r', encoding='utf-8') as f:
    html = f.read()

# 1. 替换所有"26篇"为通用描述
replacements = [
    ('从26篇稿件高频角色提取', '从团队过往稿件高频角色提取'),
    ('从26篇团队稿件中提取的金句', '从团队过往稿件中提取的金句'),
    ('26篇团队过往宣讲稿', '团队过往宣讲稿'),
    ('26篇团队稿件全文参考', '团队稿件全文参考'),
    ('26篇团队稿件全文可查', '团队稿件全文可查'),
    ('26篇团队稿件', '团队稿件'),
    ('26篇\u56e2队稿件', '团队稿件'),  # unicode variant
]

for old, new in replacements:
    html = html.replace(old, new)

# 2. 替换 stat 数字为0（init()会动态更新MANUSCRIPTS.length）
html = html.replace(
    '<span class="n" id="stat-manuscripts">26</span><span class="t">篇团队稿件</span>',
    '<span class="n" id="stat-manuscripts">0</span><span class="t">篇团队稿件</span>'
)

# 3. 找到MANUSCRIPTS数组末尾，注入脱口秀稿件
ms_start = html.index('let MANUSCRIPTS = [')
# 从起点开始计数方括号深度找到真正的数组结束位置
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

print(f'MANUSCRIPTS array: start={ms_start}, end={end_pos}')

# 构建脱口秀稿件JS条目，使用type:"talk"匹配系统分类
entries = []
for m in talk_show_ms:
    title = m['title']
    content = m['content']
    # 转换为JSON字符串以安全转义
    title_json = json.dumps(title, ensure_ascii=False)
    content_json = json.dumps(content, ensure_ascii=False)
    entry = '{type:"talk",title:' + title_json + ',content:' + content_json + '}'
    entries.append(entry)

new_entries_str = ',\n    ' + ',\n    '.join(entries)

# 注入：在end_pos（`]`字符）之前插入
new_html = html[:end_pos] + new_entries_str + '\n  ' + html[end_pos:]

with open('青言青语宣讲稿创意写作工坊.html', 'w', encoding='utf-8') as f:
    f.write(new_html)

print(f'Injected {len(entries)} talk show manuscripts')

# 验证
count = new_html.count('type:"talk"')
print(f'Verify: {count} entries with type:"talk"')

# 检查是否还有硬编码26
has_26 = '26篇' in new_html
has_26_space = '26 篇' in new_html
print(f'Still has 26: {has_26}')
print(f'Still has 26-space: {has_26_space}')
