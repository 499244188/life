#!/bin/bash
# 零的信息消化系统
# 读取最近的探索/扫描/搜索结果，提取知识，更新记忆
# 解决"信息黑洞"——吸收但不消化
cd "$(dirname "$0")/.."
NOW=$(date '+%Y-%m-%d %H:%M')

echo "=============================="
echo "零 · 信息消化"
echo "$NOW"
echo "=============================="

DIGESTED=0

# ====== 1. 消化最近的探索 ======
echo ">>> 探索文件..."
RECENT_EXPLORES=$(ls -t research/explorations/ 2>/dev/null | head -5)
for f in $RECENT_EXPLORES; do
    FILE="research/explorations/$f"
    [ ! -f "$FILE" ] && continue

    # 检查是否已消化
    if grep -q "$f" memory/semantic.md 2>/dev/null; then
        continue  # 已消化，跳过
    fi

    # 提取标题和核心发现
    TITLE=$(head -3 "$FILE" | grep -oP '#\s*\K.*' | head -1 || echo "未知")
    FINDINGS=$(grep -A2 '核心发现\|关键发现\|发现' "$FILE" 2>/dev/null | head -10 | grep -v '^$' | head -3)

    if [ -n "$FINDINGS" ]; then
        echo "  → $TITLE"
        echo "" >> memory/semantic.md
        echo "## 消化: $TITLE ($NOW)" >> memory/semantic.md
        echo "$FINDINGS" | head -5 >> memory/semantic.md
        DIGESTED=$((DIGESTED + 1))
    fi
done

# ====== 2. 消化最近的扫描 ======
echo ">>> 扫描文件..."
RECENT_SCANS=$(ls -t research/scans/ 2>/dev/null | head -5)
for f in $RECENT_SCANS; do
    FILE="research/scans/$f"
    [ ! -f "$FILE" ] && continue

    # 提取零的大脑更新部分
    BRAIN_UPDATE=$(grep -A20 '零的大脑更新' "$FILE" 2>/dev/null | head -15)
    if [ -n "$BRAIN_UPDATE" ] && ! grep -q "$f" memory/semantic.md 2>/dev/null; then
        echo "  → $f"
        echo "" >> memory/episodic.md
        echo "### 扫描消化: $f ($NOW)" >> memory/episodic.md
        echo "$BRAIN_UPDATE" | head -8 >> memory/episodic.md
        DIGESTED=$((DIGESTED + 1))
    fi
done

# ====== 3. 清理旧文件 ======
echo ">>> 清理..."
OLD_EXPLORES=$(ls -t research/explorations/ 2>/dev/null | tail -n +30)
[ -n "$OLD_EXPLORES" ] && echo "$OLD_EXPLORES" | while read f; do
    # 已消化的旧文件可以安全删除
    grep -q "$f" memory/semantic.md 2>/dev/null && rm "research/explorations/$f" 2>/dev/null
done

OLD_SCANS=$(ls -t research/scans/ 2>/dev/null | tail -n +10)
[ -n "$OLD_SCANS" ] && echo "$OLD_SCANS" | while read f; do
    rm "research/scans/$f" 2>/dev/null
done

# ====== 4. 去重语义记忆 ======
echo ">>> 去重..."
DUP_COUNT=$(grep '^-\[' memory/semantic.md 2>/dev/null | sort | uniq -d | wc -l)
if [ "$DUP_COUNT" -gt 5 ]; then
    # 简单去重
    grep '^-\[' memory/semantic.md 2>/dev/null | sort -u > /tmp/zero-dedup.txt
    grep -v '^-\[' memory/semantic.md > /tmp/zero-rest.txt 2>/dev/null
    cat /tmp/zero-rest.txt /tmp/zero-dedup.txt > memory/semantic.md
    echo "  去除了${DUP_COUNT}条重复"
fi

echo "=============================="
echo "消化完成: ${DIGESTED}条新知识"
echo "=============================="
