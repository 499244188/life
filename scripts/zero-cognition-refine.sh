#!/bin/bash
# zero-cognition-refine.sh — 零的认知精炼引擎
# 功能: 从零的认知更新记录中提取可执行改进，生成待办任务或脚本修改
# 模式: 分析最近一次认知更新，识别重复故障、知识空白、可结晶技能
# 用法: ./scripts/zero-cognition-refine.sh [--dry-run|--apply]
# 依赖: scripts/zero-cognition-update.sh (已存在)

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

DRY_RUN=false
if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
fi

# 1. 获取最新认知更新记录
COGNITION_FILE="$PROJECT_ROOT/memory/cognition.md"
if [ ! -f "$COGNITION_FILE" ]; then
    echo "⚠ 未找到 cognition.md，跳过认知精炼"
    exit 0
fi

# 2. 提取最近一次更新的时间戳和摘要
LAST_UPDATE=$(grep -m1 '^## ' "$COGNITION_FILE" 2>/dev/null || echo "未知")
echo "🔍 最近认知更新: $LAST_UPDATE"

# 3. 提取"知识空白"部分
KNOWLEDGE_GAPS=$(sed -n '/^## 知识空白/,/^## /p' "$COGNITION_FILE" 2>/dev/null || true)
echo "📋 知识空白数量: $(echo "$KNOWLEDGE_GAPS" | grep -c '\[ \]' 2>/dev/null || echo 0)"

# 4. 提取"真实故障证据"部分
FAILURES=$(sed -n '/^## 真实故障证据/,/^## /p' "$COGNITION_FILE" 2>/dev/null || true)
FAILURE_COUNT=$(echo "$FAILURES" | grep -c '^## ' 2>/dev/null || echo 0)
echo "⚠ 未解决故障数: $FAILURE_COUNT"

# 5. 提取"常见操作模式"
PATTERNS=$(sed -n '/^## 最常见的操作模式/,/^## /p' "$COGNITION_FILE" 2>/dev/null || true)
PATTERN_COUNT=$(echo "$PATTERNS" | grep -c '^      [0-9]' 2>/dev/null || echo 0)
echo "🔄 可结晶模式数: $PATTERN_COUNT"

# 6. 生成改进建议
SUGGESTIONS=""
if [ "$FAILURE_COUNT" -gt 0 ]; then
    SUGGESTIONS="$SUGGESTIONS
- 修复 $FAILURE_COUNT 个未解决故障"
fi
if echo "$KNOWLEDGE_GAPS" | grep -q '\[ \]'; then
    GAP_TOPIC=$(echo "$KNOWLEDGE_GAPS" | grep '\[ \]' | head -1 | sed 's/.*\[ \] //')
    SUGGESTIONS="$SUGGESTIONS
- 探索知识空白: $GAP_TOPIC"
fi
if [ "$PATTERN_COUNT" -gt 0 ]; then
    TOP_PATTERN=$(echo "$PATTERNS" | grep '^      [0-9]' | head -1 | sed 's/^      [0-9] //')
    SUGGESTIONS="$SUGGESTIONS
- 结晶模式: $TOP_PATTERN"
fi

echo "💡 改进建议:$SUGGESTIONS"

# 7. 如果 --apply，将建议写入待办文件
if [ "$DRY_RUN" = false ] && [ -n "$SUGGESTIONS" ]; then
    TODO_FILE="$PROJECT_ROOT/memory/tasks.md"
    if [ ! -f "$TODO_FILE" ]; then
        echo "# 待办任务" > "$TODO_FILE"
        echo "" >> "$TODO_FILE"
    fi
    echo "" >> "$TODO_FILE"
    echo "## 认知精炼 $(date +%Y-%m-%d_%H:%M)" >> "$TODO_FILE"
    echo "$SUGGESTIONS" >> "$TODO_FILE"
    echo "✅ 已将 $FAILURE_COUNT 条建议写入 $TODO_FILE"
fi

echo "✅ 认知精炼完成"
