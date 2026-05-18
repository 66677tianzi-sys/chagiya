#!/bin/bash
# ============================================
# 一键部署脚本
# 用法：在终端运行 ./deploy.sh
# 写新文章：在 articles/ 下新建 .md 文件
# 可选在文件顶部添加 front matter：
#   ---
#   title: 标题
#   tags: 标签1, 标签2
#   excerpt: 摘要
#   ---
# ============================================

cd "$(dirname "$0")"

echo ""
echo "=== 博客部署工具 ==="
echo ""

# 检查是否有新的 .md 文件
NEW_COUNT=0
for md_file in articles/*.md; do
    id=$(basename "$md_file" .md)
    if ! grep -q "\"id\": \"$id\"" data/articles.json 2>/dev/null; then
        echo "[新文章] $md_file"
        NEW_COUNT=$((NEW_COUNT + 1))
    fi
done

# 用 Python 更新文章列表
echo ""
python -c "
import json, os, re, glob, datetime, sys
sys.stdout.reconfigure(encoding='utf-8')

articles_file = 'data/articles.json'
articles_dir = 'articles'

# 读取现有列表
try:
    with open(articles_file, 'r', encoding='utf-8') as f:
        existing = json.load(f)
except:
    existing = []

existing_ids = {a['id'] for a in existing}

# 扫描 .md 文件
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

    # 解析 front matter
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

    # 从正文提取标题
    if title == file_id:
        m = re.search(r'^#\s+(.+)$', body, re.MULTILINE)
        if m: title = m.group(1).strip()

    # 从正文提取摘要
    if not excerpt:
        for line in body.split('\n'):
            line = line.strip()
            if line and not line.startswith('#') and not line.startswith('>') and not line.startswith('-') and not line.startswith('*') and not re.match(r'^\d+\.', line):
                excerpt = line[:120]
                break
        if not excerpt: excerpt = '暂无摘要'

    new_articles.append({
        'id': file_id,
        'title': title,
        'date': date_str,
        'tags': tags,
        'excerpt': excerpt
    })
    print('  + ' + title)

# 合并并排序（按日期降序）
all_articles = existing + new_articles
all_articles.sort(key=lambda a: a['date'], reverse=True)

with open(articles_file, 'w', encoding='utf-8') as f:
    json.dump(all_articles, f, ensure_ascii=False, indent=2)

if new_articles:
    print('已添加 ' + str(len(new_articles)) + ' 篇新文章')
else:
    print('没有发现新文章')
"

# 推送到 GitHub
git add -A

if git diff --cached --quiet; then
    echo ""
    echo "没有需要部署的更改。"
    exit 0
fi

echo ""
echo "更改的文件："
git diff --cached --stat
echo ""

git commit -m "update: blog content"

echo ""
echo "正在推送到 GitHub..."
if git push; then
    echo ""
    echo "部署完成！"
    echo "https://66677tianzi-sys.github.io/chagiya/"
    echo ""
else
    echo ""
    echo "推送失败，请检查网络连接。"
    exit 1
fi
