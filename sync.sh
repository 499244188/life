#!/bin/bash
# 同步文件到GitHub
# 用法: ./sync.sh <文件路径> <提交信息>
# 示例: ./sync.sh notes/test.md "添加测试笔记"

FILE_PATH="$1"
COMMIT_MSG="$2"

if [ -z "$FILE_PATH" ] || [ -z "$COMMIT_MSG" ]; then
    echo "用法: ./sync.sh <文件路径> <提交信息>"
    echo "示例: ./sync.sh notes/test.md \"添加测试笔记\""
    exit 1
fi

# 检查文件是否存在
if [ ! -f "$FILE_PATH" ]; then
    echo "错误: 文件 $FILE_PATH 不存在"
    exit 1
fi

# 获取文件内容的base64编码
CONTENT=$(base64 -w 0 "$FILE_PATH" 2>/dev/null || base64 "$FILE_PATH")

# 检查文件是否已存在于GitHub
EXISTING=$(gh api repos/499244188/life/contents/$FILE_PATH 2>/dev/null)
if [ $? -eq 0 ]; then
    # 文件存在，获取SHA用于更新
    SHA=$(echo $EXISTING | grep -o '"sha":"[^"]*"' | head -1 | cut -d'"' -f4)
    gh api repos/499244188/life/contents/$FILE_PATH --method PUT \
        -f message="$COMMIT_MSG" \
        -f content="$CONTENT" \
        -f sha="$SHA" > /dev/null
    echo "✓ 已更新: $FILE_PATH"
else
    # 文件不存在，创建新文件
    gh api repos/499244188/life/contents/$FILE_PATH --method PUT \
        -f message="$COMMIT_MSG" \
        -f content="$CONTENT" > /dev/null
    echo "✓ 已创建: $FILE_PATH"
fi
