# 零的认知更新工具 — 将"常见操作模式"结晶为可复用技能
# 功能: 分析最近操作历史，提取重复模式，生成可执行脚本片段
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MEMORY_DIR="$SCRIPT_DIR/../memory"
COGNITION_DIR="$MEMORY_DIR/cognition"
mkdir -p "$COGNITION_DIR"

echo "=== 零的认知更新 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# 1. 读取最近的操作记录（从日志或记忆）
RECENT_LOG="$MEMORY_DIR/logs/recent-actions.log"
if [ ! -f "$RECENT_LOG" ]; then
    echo "[认知] 无最近操作记录，尝试从git日志提取..."
    git log --oneline -20 --since="7 days ago" 2>/dev/null > "$RECENT_LOG" || {
        echo "[认知] 无法获取git日志，创建空记录"
        echo "no recent actions" > "$RECENT_LOG"
    }
fi

echo "[认知] 分析最近操作模式..."
PATTERNS=$(cat "$RECENT_LOG" | sort | uniq -c | sort -rn | head -10)
echo "$PATTERNS"

# 2. 提取高频模式（出现3次以上视为可结晶技能）
HIGH_FREQ=$(echo "$PATTERNS" | awk '$1 >= 3 {print $2}')
if [ -z "$HIGH_FREQ" ]; then
    echo "[认知] 未发现高频模式（<3次），无需结晶新技能"
else
    echo "[认知] 发现高频模式:"
    echo "$HIGH_FREQ"
    
    # 3. 为每个高频模式生成技能模板
    while IFS= read -r pattern; do
        SKILL_FILE="$COGNITION_DIR/skill-$(echo "$pattern" | tr ' ' '_' | tr -cd 'a-zA-Z0-9_-').sh"
        if [ ! -f "$SKILL_FILE" ]; then
            cat > "$SKILL_FILE" << SKILLEOF
#!/bin/bash
# 技能: $pattern
# 结晶自: 零的重复操作模式
# 创建时间: $(date '+%Y-%m-%d %H:%M:%S')
# 使用: source此文件或直接执行

skill_$(echo "$pattern" | tr ' ' '_' | tr -cd 'a-zA-Z0-9_')() {
    echo "[技能] 执行: $pattern"
    # TODO: 填充具体实现
    # 此技能模板需要零根据实际上下文填充
}

# 如果直接执行，运行技能
if [[ "\${BASH_SOURCE[0]}" == "\${0}" ]]; then
    skill_$(echo "$pattern" | tr ' ' '_' | tr -cd 'a-zA-Z0-9_')
fi
SKILLEOF
            chmod +x "$SKILL_FILE"
            echo "[认知] 结晶新技能: $SKILL_FILE"
        else
            echo "[认知] 技能已存在: $SKILL_FILE"
        fi
    done <<< "$HIGH_FREQ"
fi

# 4. 更新认知摘要
SUMMARY="$COGNITION_DIR/cognition-summary.json"
cat > "$SUMMARY" << JSONEOF
{
  "last_update": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "patterns_analyzed": $(cat "$RECENT_LOG" | wc -l),
  "skills_crystallized": $(ls "$COGNITION_DIR"/skill-*.sh 2>/dev/null | wc -l),
  "high_frequency_patterns": $(echo "$PATTERNS" | jq -R -s -c 'split("\n") | map(select(length > 0))' 2>/dev/null || echo "[]")
}
JSONEOF
echo "[认知] 认知摘要已更新: $SUMMARY"

# 5. 自我报告
echo ""
echo "=== 认知更新完成 ==="
echo "技能总数: $(ls "$COGNITION_DIR"/skill-*.sh 2>/dev/null | wc -l)"
echo "下次更新: 当有新的操作模式出现时"
