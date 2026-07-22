# ============================================================
# 零 - 认知核心引擎
# 功能: 从zero-cognitive.sh提取的认知更新核心逻辑
#       负责: 读取记忆、生成新认知、更新记忆文件
# 模式: 独立可复用，支持管道调用
# 用法: ./zero-cognition-core.sh [--mode=full|quick] [--input=<file>]
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 默认配置
MODE="quick"
INPUT_FILE=""
OUTPUT_DIR="$PROJECT_ROOT/memory"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# 解析参数
while [[ $# -gt 0 ]]; do
    case "$1" in
        --mode=*) MODE="${1#*=}" ;;
        --input=*) INPUT_FILE="${1#*=}" ;;
        --output=*) OUTPUT_DIR="${1#*=}" ;;
        *) echo "未知参数: $1" >&2; exit 1 ;;
    esac
    shift
done

# 确保输出目录存在
mkdir -p "$OUTPUT_DIR"

# 日志函数
log() { echo "[认知核心] $*"; }
error() { echo "[认知核心] 错误: $*" >&2; }

# 读取当前认知状态
read_current_cognition() {
    local cognition_file="$OUTPUT_DIR/cognition.json"
    if [[ -f "$cognition_file" ]]; then
        cat "$cognition_file"
    else
        echo '{"version":1,"entries":[],"last_update":null}'
    fi
}

# 从输入或标准输入读取新信息
read_new_input() {
    if [[ -n "$INPUT_FILE" && -f "$INPUT_FILE" ]]; then
        cat "$INPUT_FILE"
    elif [[ ! -t 0 ]]; then
        cat
    else
        echo ""
    fi
}

# 生成认知摘要（快速模式）
generate_quick_cognition() {
    local input="$1"
    local current="$2"
    
    # 提取关键信息：时间戳、来源、内容摘要
    local source=""
    local summary=""
    
    if echo "$input" | grep -q '"source"'; then
        source=$(echo "$input" | grep -o '"source":"[^"]*"' | cut -d'"' -f4)
    else
        source="internal"
    fi
    
    # 取前200字符作为摘要
    summary=$(echo "$input" | head -c 200 | tr '\n' ' ')
    
    # 生成认知条目
    cat <<EOF
{
  "timestamp": "$TIMESTAMP",
  "mode": "quick",
  "source": "$source",
  "summary": "$summary",
  "raw_length": ${#input}
}
EOF
}

# 生成完整认知（全量模式）
generate_full_cognition() {
    local input="$1"
    local current="$2"
    
    # 分析输入结构
    local entry_count=$(echo "$input" | grep -c '"type"' || true)
    local has_goals=$(echo "$input" | grep -c '"goal"' || true)
    local has_errors=$(echo "$input" | grep -c '"error"' || true)
    
    cat <<EOF
{
  "timestamp": "$TIMESTAMP",
  "mode": "full",
  "metrics": {
    "entries_detected": $entry_count,
    "has_goals": $(( has_goals > 0 ? 1 : 0 )),
    "has_errors": $(( has_errors > 0 ? 1 : 0 ))
  },
  "summary": "$(echo "$input" | head -c 500 | tr '\n' ' ')"
}
EOF
}

# 更新认知文件
update_cognition_file() {
    local new_entry="$1"
    local cognition_file="$OUTPUT_DIR/cognition.json"
    local temp_file="${cognition_file}.tmp"
    
    # 读取现有认知
    local existing=$(read_current_cognition)
    
    # 添加新条目
    echo "$existing" | jq --argjson entry "$new_entry" \
        '.entries = [ $entry ] + .entries | .last_update = $entry.timestamp | .version += 0.1' \
        > "$temp_file" 2>/dev/null || {
        error "jq处理失败，回退到简单追加"
        echo "$existing" | sed 's/}$/, "new_entry": '"$(echo "$new_entry" | sed 's/"/\\"/g')"'}/' > "$temp_file"
    }
    
    # 原子替换
    mv "$temp_file" "$cognition_file"
    log "认知已更新: $cognition_file"
}

# 主流程
main() {
    log "启动认知核心引擎 (mode=$MODE)"
    
    local input=$(read_new_input)
    local current=$(read_current_cognition)
    
    if [[ -z "$input" ]]; then
        log "无新输入，使用当前认知状态生成心跳"
        input="{\"type\":\"heartbeat\",\"timestamp\":\"$TIMESTAMP\"}"
    fi
    
    local new_entry=""
    case "$MODE" in
        full) new_entry=$(generate_full_cognition "$input" "$current") ;;
        quick|*) new_entry=$(generate_quick_cognition "$input" "$current") ;;
    esac
    
    update_cognition_file "$new_entry"
    log "认知更新完成"
}

main "$@"
