@echo off
cd /d "%~dp0"
chcp 65001 >nul

echo.
echo === 博客部署工具 ===
echo.

:: 用 Python 检测新文章并更新 articles.json
python -c "
import json, os, re, glob, datetime, sys
sys.stdout.reconfigure(encoding='utf-8')

articles_file = 'data/articles.json'
articles_dir = 'articles'

try:
    with open(articles_file, 'r', encoding='utf-8') as f:
        existing = json.load(f)
except:
    existing = []

existing_ids = {a['id'] for a in existing}
new_articles = []

for md_path in sorted(glob.glob(os.path.join(articles_dir, '*.md'))):
    file_id = os.path.splitext(os.path.basename(md_path))[0]
    if file_id in existing_ids:
        continue

    with open(md_path, 'r', encoding='utf-8') as f:
        content = f.read()

    title = file_id
    excerpt = ''
    tags = ['未分类']
    body = content
    mtime = os.path.getmtime(md_path)
    date_str = datetime.date.fromtimestamp(mtime).isoformat()

    if content.startswith('---'):
        parts = content.split('---', 2)
        if len(parts) >= 3:
            fm = parts[1]
            body = parts[2]
            m = re.search(r'^title:\s*(.+)$', fm, re.MULTILINE)
            if m: title = m.group(1).strip().strip('\"').strip(\"'\")
            m = re.search(r'^tags:\s*(.+)$', fm, re.MULTILINE)
            if m:
                raw = m.group(1).strip()
                tags = [t.strip().strip('\"').strip(\"'\").strip('[]') for t in raw.split(',') if t.strip()]
            m = re.search(r'^excerpt:\s*(.+)$', fm, re.MULTILINE)
            if m: excerpt = m.group(1).strip().strip('\"').strip(\"'\")

    if title == file_id:
        m = re.search(r'^#\s+(.+)$', body, re.MULTILINE)
        if m: title = m.group(1).strip()

    if not excerpt:
        for line in body.split('\n'):
            line = line.strip()
            if line and not line.startswith('#') and not line.startswith('>') and not line.startswith('-') and not line.startswith('*') and not re.match(r'^\d+\.', line):
                excerpt = line[:120]
                break
        if not excerpt: excerpt = '暂无摘要'

    new_articles.append({
        'id': file_id, 'title': title, 'date': date_str,
        'tags': tags, 'excerpt': excerpt
    })
    print('  + ' + title)

all_articles = existing + new_articles
all_articles.sort(key=lambda a: a['date'], reverse=True)

with open(articles_file, 'w', encoding='utf-8') as f:
    json.dump(all_articles, f, ensure_ascii=False, indent=2)

if new_articles:
    print('已添加 ' + str(len(new_articles)) + ' 篇新文章')
else:
    print('没有发现新文章')
"

if %errorlevel% neq 0 (
    echo Python 运行出错，请确保已安装 Python。
    pause
    exit /b
)

echo.

:: 推送到 GitHub
git add -A

git diff --cached --quiet
if %errorlevel% equ 0 (
    echo 没有需要部署的更改。
    pause
    exit /b
)

echo 更改的文件：
git diff --cached --stat
echo.

git commit -m "update: blog content"

echo.
echo 正在推送到 GitHub...
git push

if %errorlevel% equ 0 (
    echo.
    echo 部署完成！
    echo https://66677tianzi-sys.github.io/chagiya/
) else (
    echo.
    echo 推送失败，请检查网络连接。
)

pause
