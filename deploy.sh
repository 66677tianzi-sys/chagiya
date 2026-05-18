#!/bin/bash
# ============================================
# 一键部署脚本 - 提交并推送博客更新
# ============================================

cd "$(dirname "$0")"

echo ""
echo "🚀 正在部署博客更新..."
echo ""

# 添加所有更改
git add -A

# 检查是否有更改
if git diff --cached --quiet; then
    echo "⚠️  没有检测到更改，无需部署。"
    exit 0
fi

# 显示更改的文件
echo "📄 更改的文件："
git diff --cached --stat
echo ""

# 提交
git commit -m "update: blog content"

# 推送到 GitHub
git push

echo ""
echo "✅ 部署完成！"
echo "   https://66677tianzi-sys.github.io/chagiya/"
