# -*- coding: utf-8 -*-
"""将稿件JSON数据注入到HTML文件中"""
import json
import os

html_path = r'D:\桌面\青言青语宣创\青言青语宣讲稿创意写作工坊.html'
json_path = r'D:\桌面\青言青语宣创\manuscripts_data.json'

# 读取稿件数据
with open(json_path, 'r', encoding='utf-8') as f:
    manuscripts = json.load(f)

# 转换为JS数组字符串
# 使用 json.dumps 确保正确的JSON格式，然后赋值给JS变量
js_data = json.dumps(manuscripts, ensure_ascii=False)

# 读取HTML文件
with open(html_path, 'r', encoding='utf-8') as f:
    html = f.read()

# 替换占位符
placeholder = 'let MANUSCRIPTS = []; /* MANUSCRIPT_DATA_PLACEHOLDER */'
replacement = f'let MANUSCRIPTS = {js_data};'

if placeholder in html:
    html = html.replace(placeholder, replacement)
    # 写回文件
    with open(html_path, 'w', encoding='utf-8') as f:
        f.write(html)
    print(f'成功注入 {len(manuscripts)} 篇稿件数据！')
    print(f'HTML文件大小: {os.path.getsize(html_path) / 1024:.1f} KB')
else:
    print('错误：未找到占位符！')
