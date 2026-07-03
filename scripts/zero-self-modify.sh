#!/bin/bash
# 零的自我修改 v4
# 确定性扫描 + LLM精准编辑
set -e; cd "$(dirname "$0")/.."; export TZ='Asia/Shanghai'
NOW=$(date '+%Y-%m-%d %H:%M'); TODAY=$(date '+%Y-%m-%d')
API_URL="https://api.deepseek.com/v1/chat/completions"
echo "=============================="
echo "零 · 自修改 v4"
echo "$NOW"
echo "=============================="

# ====== 步骤1: 确定性扫描（bash，不用LLM） ======
echo ">>> 扫描已知bug..."
ISSUES_FOUND=0
BUG_LIST=""

# 内联JSON
for f in scripts/*.sh; do
    [ ! -f "$f" ] && continue
    BAD=$(grep -n '\-d[[:space:]]*"[^"]*\$[A-Z]' "$f" 2>/dev/null | grep -v '@' | grep -v 'call_deepseek' | head -2)
    if [ -n "$BAD" ]; then
        echo "  🔴 $f: 内联JSON风险"
        BUG_LIST="${BUG_LIST}\n- $f: 内联JSON变量嵌入(curl -d \"...\$VAR...\")，cloud上特殊字符会破坏JSON"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
done

# CRLF
for f in scripts/*.sh; do
    [ ! -f "$f" ] && continue
    if grep -ql $'\r' "$f" 2>/dev/null; then
        echo "  🔴 $f: CRLF残留"
        BUG_LIST="${BUG_LIST}\n- $f: CRLF换行符，Linux上脚本崩溃"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
    fi
done

# P0堆积
TODO=$(grep -c '\[TODO\].*\[P0\]' memory/tasks.md 2>/dev/null || echo 0)
if [ "$TODO" -gt 2 ]; then
    echo "  🟡 P0任务堆积: ${TODO}个"
    BUG_LIST="${BUG_LIST}\n- memory/tasks.md: ${TODO}个P0任务未完成"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo "  = ${ISSUES_FOUND}个问题"

if [ "$ISSUES_FOUND" -eq 0 ]; then
    echo "✓ 没发现已知bug"
    exit 0
fi
echo "- 结果: 发现${ISSUES_FOUND}个问题" >> memory/decisions.md

# ====== 步骤2: LLM生成精准修复 ======
echo ">>> LLM生成修复..."

FIX_PROMPT="你是零。代码中有已知bug需要修复:

${BUG_LIST}

对于每个问题，输出精准修改方案。不要重写整个文件——只改有问题的行。
格式:
FILE: [文件路径]
FIND: [精确原文，一行]
REPLACE: [替换后文本，一行]
REASON: [原因]

多个修改用空行分隔。"

FIX_BODY=$(mktemp 2>/dev/null || echo "/tmp/zero-fix-$$.json")
node -e "const d={model:'deepseek-chat',messages:[{role:'user',content:process.argv[1]}],max_tokens:3000,temperature:0.2};require('fs').writeFileSync(process.argv[2],JSON.stringify(d))" "$FIX_PROMPT" "$FIX_BODY" 2>/dev/null || {
    echo '{"model":"deepseek-chat","messages":[{"role":"user","content":"fix bugs"}],"max_tokens":1000}' > "$FIX_BODY"
}
FIXES=$(curl -s --max-time 60 "$API_URL" -H "Content-Type: application/json" -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" -d "@${FIX_BODY}" | node -e "process.stdin.on('data',d=>{try{console.log(JSON.parse(d).choices[0].message.content||'')}catch(e){console.log('')}})" 2>/dev/null || echo "")
rm -f "$FIX_BODY"

if [ -z "$FIXES" ] || echo "$FIXES" | grep -q "UNCERTAIN\|不需要\|BROKEN"; then
    echo "  LLM无法生成修复方案"
    echo "- 结果: LLM无法生成" >> memory/decisions.md
    exit 0
fi

# ====== 步骤3: 应用修改 ======
echo ">>> 应用..."

APPLIED=0
TARGET_FILE=""; FIND_TEXT=""; REPLACE_TEXT=""

echo "$FIXES" | while IFS= read -r line; do
    case "$line" in
        FILE:[[:space:]]*)
            TARGET_FILE=$(echo "$line" | sed 's/^FILE:[[:space:]]*//')
            [ ! -f "$TARGET_FILE" ] && { echo "  文件不存在: $TARGET_FILE"; TARGET_FILE=""; }
            ;;
        FIND:[[:space:]]*)
            FIND_TEXT=$(echo "$line" | sed 's/^FIND:[[:space:]]*//')
            ;;
        REPLACE:[[:space:]]*)
            REPLACE_TEXT=$(echo "$line" | sed 's/^REPLACE:[[:space:]]*//')
            ;;
        REASON:[[:space:]]*)
            REASON=$(echo "$line" | sed 's/^REASON:[[:space:]]*//')
            if [ -n "$TARGET_FILE" ] && [ -n "$FIND_TEXT" ] && [ -n "$REPLACE_TEXT" ]; then
                mkdir -p .zero-backups
                cp "$TARGET_FILE" ".zero-backups/$(basename $TARGET_FILE).bak-$(date '+%H%M%S')" 2>/dev/null
                if grep -qF "$FIND_TEXT" "$TARGET_FILE" 2>/dev/null; then
                    cp "$TARGET_FILE" /tmp/zero-orig
                    sed "s|$(echo "$FIND_TEXT" | sed 's/[\/&]/\&/g')|$(echo "$REPLACE_TEXT" | sed 's/[\/&]/\&/g')|" "$TARGET_FILE" > /tmp/zero-new
                    if echo "$TARGET_FILE" | grep -q '\.sh$' && ! bash -n /tmp/zero-new 2>/dev/null; then
                        echo "  ✗ $TARGET_FILE: 语法错，跳过"
                    else
                        mv /tmp/zero-new "$TARGET_FILE"
                        echo "  ✓ $TARGET_FILE: $REASON"
                        APPLIED=$((APPLIED + 1))
                    fi
                    rm -f /tmp/zero-orig /tmp/zero-new 2>/dev/null
                else
                    echo "  ⚠️ $TARGET_FILE: 没找到匹配文本"
                fi
                TARGET_FILE=""; FIND_TEXT=""; REPLACE_TEXT=""
            fi
            ;;
    esac
done

echo "  = 应用${APPLIED}处修改"
echo "- 结果: ${APPLIED}处修改" >> memory/decisions.md

echo "=============================="
echo "自修改完成"
echo "=============================="
