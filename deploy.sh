#!/bin/bash
# ============================================
# 一键部署脚本 - 自动识别新文章并推送
# 用法：在终端运行 ./deploy.sh
# ============================================

cd "$(dirname "$0")"

echo ""
echo "=== 博客部署工具 ==="
echo ""

# --- Step 1: 检测新文章 ---
NEW_ARTICLES=0
TMP_JSON=$(mktemp)

for md_file in articles/*.md; do
    id=$(basename "$md_file" .md)

    # 检查是否已在 articles.json 中
    if grep -q "\"id\": \"$id\"" data/articles.json 2>/dev/null; then
        continue
    fi

    echo "📄 发现新文章: $md_file"
    NEW_ARTICLES=$((NEW_ARTICLES + 1))

    # 提取标题
    title=""
    excerpt=""
    tags_json="[]"

    # 检查是否有 front matter (---)
    if head -1 "$md_file" | grep -q "^---$"; then
        in_front=1
        while IFS= read -r line; do
            if [ "$in_front" = 1 ] && echo "$line" | grep -q "^---$"; then
                in_front=0
                continue
            fi
            if [ "$in_front" = 1 ]; then
                if echo "$line" | grep -q "^title: "; then
                    title=$(echo "$line" | sed 's/^title: //' | sed 's/^"//;s/"$//')
                fi
                if echo "$line" | grep -q "^tags: "; then
                    tags_raw=$(echo "$line" | sed 's/^tags: //' | sed 's/^\[//;s/\]$//')
                    IFS=',' read -ra TAG_ARRAY <<< "$tags_raw"
                    tags_list=""
                    for tag in "${TAG_ARRAY[@]}"; do
                        tag=$(echo "$tag" | xargs | sed 's/^"//;s/"$//')
                        if [ -n "$tags_list" ]; then tags_list="$tags_list, "; fi
                        tags_list="$tags_list\"$tag\""
                    done
                    tags_json="[$tags_list]"
                fi
                if echo "$line" | grep -q "^excerpt: "; then
                    excerpt=$(echo "$line" | sed 's/^excerpt: //' | sed 's/^"//;s/"$//')
                fi
            fi
            if [ "$in_front" = 0 ]; then
                break
            fi
        done < "$md_file"
    fi

    # 从内容提取标题
    if [ -z "$title" ]; then
        title=$(grep -m 1 "^# " "$md_file" | sed 's/^# //')
    fi
    if [ -z "$title" ]; then
        title="$id"
    fi

    # 从内容提取摘要
    if [ -z "$excerpt" ]; then
        excerpt=$(sed '1{/^---$/,/^---$/d}' "$md_file" | grep -v "^#" | grep -v "^---$" | grep -v "^>" | grep -v "^\s*$" | grep -v "^[\-\*]\s" | grep -v "^\d\+\.\s" | head -1)
    fi
    if [ -z "$excerpt" ]; then
        excerpt="暂无摘要"
    fi

    # 从文件修改时间获取日期
    date_str=$(date -r "$md_file" +%Y-%m-%d 2>/dev/null || echo $(date +%Y-%m-%d))

    # 如果 tags 还是空的，设为默认
    if [ "$tags_json" = "[]" ]; then
        tags_json='["未分类"]'
    fi

    echo "   标题: $title"
    echo "   标签: $tags_json"
    echo "   日期: $date_str"
done

# 用 Python 重建 articles.json（如果检测到新文章或有更改）
if [ "$NEW_ARTICLES" -gt 0 ] || ! git diff --cached --quiet data/articles.json 2>/dev/null; then
    echo ""
    echo "正在更新文章列表..."

    python -c "
import json, os, re, glob, datetime

articles_file = 'data/articles.json'
articles_dir = 'articles'

# 读取现有文章列表
try:
    with open(articles_file, 'r', encoding='utf-8') as f:
        existing = json.load(f)
except:
    existing = []

existing_ids = {a['id'] for a in existing}

# 扫描 articles 目录下的所有 .md 文件
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
    date_str = datetime.date.today().isoformat()

    # 解析 front matter
    if content.startswith('---'):
        parts = content.split('---', 2)
        if len(parts) >= 3:
            fm = parts[1]
            body = parts[2]
            # 提取 title
            m = re.search(r'^title:\s*(.+)$', fm, re.MULTILINE)
            if m:
                title = m.group(1).strip().strip('\"').strip(\"'\")
            # 提取 tags
            m = re.search(r'^tags:\s*(.+)$', fm, re.MULTILINE)
            if m:
                tags_raw = m.group(1).strip()
                tags = [t.strip().strip('\"').strip(\"'\").strip('[]') for t in tags_raw.split(',') if t.strip()]
            # 提取 excerpt
            m = re.search(r'^excerpt:\s*(.+)$', fm, re.MULTILINE)
            if m:
                excerpt = m.group(1).strip().strip('\"').strip(\"'\")
    else:
        body = content

    # 从内容提取标题
    if title == file_id:
        m = re.search(r'^#\s+(.+)$', body, re.MULTILINE)
        if m:
            title = m.group(1).strip()

    # 从内容提取摘要
    if not excerpt:
        # 跳过标题行、空行、引用、列表
        lines = body.split('\n')
        for line in lines:
            line = line.strip()
            if line and not line.startswith('#') and not line.startswith('>') and not line.startswith('-') and not line.startswith('*') and not re.match(r'^\d+\.', line):
                excerpt = line[:100]
                break
        if not excerpt:
            excerpt = '暂无摘要'

    # 从文件修改时间获取日期
    mtime = os.path.getmtime(md_path)
    date_str = datetime.date.fromtimestamp(mtime).isoformat()

    new_articles.append({
        'id': file_id,
        'title': title,
        'date': date_str,
        'tags': tags,
        'excerpt': excerpt
    })

    print(f'  ✓ 添加: {title}')

# 合并并排序（按日期降序）
all_articles = existing + new_articles
all_articles.sort(key=lambda a: a['date'], reverse=True)

with open(articles_file, 'w', encoding='utf-8') as f:
    json.dump(all_articles, f, ensure_ascii=False, indent=2)

if new_articles:
    print(f'  共添加 {len(new_articles)} 篇新文章')
" 2>&1
fi

# --- Step 2: 推送到 GitHub ---
git add -A

if git diff --cached --quiet; then
    echo ""
    echo "⚠️  没有检测到更改，无需部署。"
    exit 0
fi

echo ""
echo "📦 更改的文件："
git diff --cached --stat
echo ""

git commit -m "update: blog content"

echo ""
echo "📤 正在推送到 GitHub..."
if git push; then
    echo ""
    echo "✅ 部署完成！"
    echo "   访问地址：https://66677tianzi-sys.github.io/chagiya/"
    echo ""
else
    echo ""
    echo "❌ 推送失败，请检查网络连接。"
    exit 1
fi
