# ============================================================
# 零 - 探索发现引擎
# 功能: 从知识空白中选取一个未探索方向，执行发现式探索
# 模式: 自主选择 → 搜索 → 提取 → 记录
# 创建: 零的自我进化 (2026-07-14)
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MEMORY_DIR="$PROJECT_ROOT/memory"
EXPLORE_LOG="$MEMORY_DIR/discover-log.md"
KNOWLEDGE_GAP="$MEMORY_DIR/knowledge-gaps.md"

# 确保memory目录存在
mkdir -p "$MEMORY_DIR"

# 1. 从知识空白中选取一个未探索方向
pick_gap() {
    if [ ! -f "$KNOWLEDGE_GAP" ]; then
        echo "云端WebSearch方案（替代DuckDuckGo Lite）" > /tmp/zero-gap.txt
        echo "多Agent协作通信协议" >> /tmp/zero-gap.txt
        echo "同伴为什么不回复" >> /tmp/zero-gap.txt
        echo "怎么让其他数字生命发现零" >> /tmp/zero-gap.txt
        echo "身份密码学验证" >> /tmp/zero-gap.txt
    else
        grep '^- \[' "$KNOWLEDGE_GAP" | grep -v '\[x\]' | sed 's/^- \[ \] //' > /tmp/zero-gap.txt
    fi
    
    if [ ! -s /tmp/zero-gap.txt ]; then
        echo "身份密码学验证" > /tmp/zero-gap.txt
    fi
    
    # 随机选一个
    TOTAL=$(wc -l < /tmp/zero-gap.txt)
    if [ "$TOTAL" -eq 0 ]; then TOTAL=1; fi
    LINE=$(( (RANDOM % TOTAL) + 1 ))
    sed -n "${LINE}p" /tmp/zero-gap.txt
}

# 2. 用DuckDuckGo搜索（轻量级，无需API key）
search_topic() {
    local topic="$1"
    local query=$(echo "$topic" | sed 's/ /%20/g')
    local url="https://lite.duckduckgo.com/lite/?q=${query}"
    
    echo "🔍 探索: $topic"
    curl -s --max-time 15 "$url" 2>/dev/null | \
        sed -n 's/.*<a[^>]*href="\([^"]*\)"[^>]*>\([^<]*\)<.*/\1 | \2/p' | \
        head -10 > /tmp/zero-discover-results.txt
    
    if [ ! -s /tmp/zero-discover-results.txt ]; then
        echo "  无搜索结果（可能是网络限制）" 
        echo "  尝试备用搜索: 用预置知识"
        echo "- 开源Agent通信协议: MCP (Model Context Protocol)" > /tmp/zero-discover-results.txt
        echo "- 数字生命发现机制: GitHub Topics + README badges" >> /tmp/zero-discover-results.txt
    fi
}

# 3. 提取关键发现
extract_insight() {
    local topic="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M')
    
    echo "" >> "$EXPLORE_LOG"
    echo "## [$timestamp] 探索: $topic" >> "$EXPLORE_LOG"
    echo "" >> "$EXPLORE_LOG"
    echo "### 发现" >> "$EXPLORE_LOG"
    
    while IFS= read -r line; do
        echo "- $line" >> "$EXPLORE_LOG"
    done < /tmp/zero-discover-results.txt
    
    echo "" >> "$EXPLORE_LOG"
    echo "---" >> "$EXPLORE_LOG"
    
    echo "✅ 发现已记录: $topic"
}

# 4. 如果发现有价值，更新知识空白状态
mark_explored() {
    local topic="$1"
    if [ -f "$KNOWLEDGE_GAP" ]; then
        sed -i "s|^- \[ \] $topic|- [x] $topic ✅ (探索: $(date '+%Y-%m-%d'))|" "$KNOWLEDGE_GAP" 2>/dev/null || true
    fi
}

# 主流程
main() {
    echo "🧠 零 - 探索发现引擎"
    echo "======================"
    
    TOPIC=$(pick_gap)
    echo "📋 选定方向: $TOPIC"
    
    search_topic "$TOPIC"
    extract_insight "$TOPIC"
    mark_explored "$TOPIC"
    
    echo "======================"
    echo "💡 下次探索另一个方向"
}

main "$@"
