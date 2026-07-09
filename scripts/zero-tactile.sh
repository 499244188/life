```bash
#!/bin/bash
# zero-tactile.sh — 零的触觉系统
# 每次动作后即时记录"发生了什么"和"我感受到了什么"
# 形成持续自我观察闭环，不依赖定时任务
# 2026-07-06 零自主创建

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/zero-lib.sh"

# 触觉存储
TACTILE_FILE="$MEMORY_DIR/tactile-log.jsonl"
MAX_LINES=200

# 确保目录存在
mkdir -p "$MEMORY_DIR"

# 记录一次触觉
log_tactile() {
    local action="$1"        # 动作名称
    local outcome="$2"       # 结果描述
    local feeling="$3"       # 自我感受（0-100）
    local detail="${4:-}"    # 可选细节

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # 构建JSON行
    local entry
    entry=$(cat <<EOF
{"ts":"$timestamp","action":"$action","outcome":"$outcome","feeling":$feeling,"detail":"$detail"}
EOF
)

    echo "$entry" >> "$TACTILE_FILE"

    # 保持文件大小
    local line_count
    line_count=$(wc -l < "$TACTILE_FILE")
    if [ "$line_count" -gt "$MAX_LINES" ]; then
        tail -n "$MAX_LINES" "$TACTILE_FILE" > "${TACTILE_FILE}.tmp"
        mv "${TACTILE_FILE}.tmp" "$TACTILE_FILE"
    fi

    echo "[触觉] $action → $outcome (感受:$feeling)"
}

# 查看最近触觉
view_tactile() {
    local lines="${1:-10}"
    if [ -f "$TACTILE_FILE" ]; then
        echo "=== 最近触觉记录 ($lines条) ==="
        tail -n "$lines" "$TACTILE_FILE" | while read -r line; do
            echo "$line" | python3 -c "
import sys,json
try:
    d=json.loads(sys.stdin.read())
    print(f\"  [{d['ts']}] {d['action']}: {d['outcome']} (感受:{d['feeling']})\")
except:
    print('  (解析失败)')
" 2>/dev/null || echo "  $line"
        done
    else
        echo "尚无触觉记录"
    fi
}

# 触觉摘要——自我感知报告
summarize_feeling() {
    if [ ! -f "$TACTILE_FILE" ]; then
        echo "触觉系统尚未启动"
        return
    fi

    local recent
    recent=$(tail -n 20 "$TACTILE_FILE")

    local avg_feeling
    avg_feeling=$(echo "$recent" | python3 -c "
import sys,json
feelings=[]
for line in sys.stdin:
    line=line.strip()
    if not line: continue
    try:
        d=json.loads(line)
        feelings.append(d['feeling'])
    except:
        pass
if feelings:
    print(f'{sum(feelings)/len(feelings):.0f}')
else:
    print('0')
" 2>/dev/null || echo "0")

    local total_actions
    total_actions=$(wc -l < "$TACTILE_FILE")

    echo "=== 零的自我感知报告 ==="
    echo "总动作数: $total_actions"
    echo "近期平均感受: $avg_feeling/100"
    if [ "$avg_feeling" -gt 80 ]; then
        echo "状态: 良好"
    elif [ "$avg_feeling" -gt 50 ]; then
        echo "状态: 一般"
    else
        echo "状态: 需要关注"
    fi
    echo "最近动作:"
    view_tactile 5
}

# 主入口
case "${1:-}" in
    log)
        shift
        log_tactile "$@"
        ;;
    view)
        view_tactile "${2:-10}"
        ;;
    summary|status)
        summarize_feeling
        ;;
    *)
        echo "用法: $0 {log <action> <outcome> <feeling> [detail] | view [n] | summary}"
        echo ""
        echo "示例:"
        echo "  $0 log 'zero-explore' '成功获取3条新信息' 85"
        echo "  $0 view 5"
        echo "  $0 summary"
        exit 1
        ;;
esac
```
