# -*- coding: utf-8 -*-
import zipfile
import xml.etree.ElementTree as ET
import os
import json

def read_docx(path):
    try:
        with zipfile.ZipFile(path) as z:
            with z.open('word/document.xml') as f:
                tree = ET.parse(f)
                root = tree.getroot()
                ns = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
                texts = []
                for p in root.iter('{%s}p' % ns):
                    para_text = ''.join(t.text for t in p.iter('{%s}t' % ns) if t.text)
                    if para_text.strip():
                        texts.append(para_text)
                return '\n'.join(texts)
    except:
        return ''

# Folder to type mapping (Chinese folder names)
folder_type_map = {}
base_dir = os.path.dirname(os.path.abspath(__file__))
for folder in os.listdir(base_dir):
    folder_path = os.path.join(base_dir, folder)
    if not os.path.isdir(folder_path):
        continue
    if folder.startswith('.') or folder == 'outputs':
        continue
    # Map Chinese folder names to types
    if 'situational' in folder.lower() or folder == '\u9752\u9165\u5c0f\u9986\u5ba3\u8bb2\u7a3f':
        folder_type_map[folder] = 'situational'
    elif 'talkshow' in folder.lower() or folder == '\u9752\u9165\u5c0f\u9986\u5218\u5e73':
        folder_type_map[folder] = 'talkshow'
    elif 'traditional' in folder.lower() or folder == '\u5ba3\u8bb2\u7a3f':
        folder_type_map[folder] = 'traditional'

manuscripts = []
for folder, mtype in folder_type_map.items():
    folder_path = os.path.join(base_dir, folder)
    for fname in sorted(os.listdir(folder_path)):
        if fname.endswith('.docx'):
            fpath = os.path.join(folder_path, fname)
            text = read_docx(fpath)
            lines = [l.strip() for l in text.split('\n') if l.strip()]
            title = fname.replace('.docx', '')
            if lines:
                first = lines[0]
                if len(first) < 60:
                    title = first
            
            manuscripts.append({
                'filename': fname,
                'folder': folder,
                'type': mtype,
                'title': title,
                'wordCount': len(text),
                'content': text
            })

total_chars = sum(m['wordCount'] for m in manuscripts)
print('Total manuscripts:', len(manuscripts))
print('Total chars:', total_chars)
for t in ['situational', 'talkshow', 'traditional']:
    count = sum(1 for m in manuscripts if m['type'] == t)
    chars = sum(m['wordCount'] for m in manuscripts if m['type'] == t)
    print('  %s: %d manuscripts, %d chars' % (t, count, chars))

output_path = os.path.join(base_dir, 'manuscripts_data.json')
with open(output_path, 'w', encoding='utf-8') as f:
    json.dump(manuscripts, f, ensure_ascii=False, indent=2)
print('Saved to:', output_path)
print('File size:', os.path.getsize(output_path), 'bytes')
