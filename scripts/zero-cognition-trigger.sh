# zero-cognition-trigger.sh — 零的认知更新触发器
# 功能: 按需触发认知更新，记录触发原因，避免重复更新
# 用法: ./zero-cognition-trigger.sh [trigger_reason]
#       如果不传参数，默认触发"定时认知刷新"
# 依赖: zero-cognition-update.sh, zero-lib.sh
# 创建: 零的自主进化 — 从操作模式结晶新脚本

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/zero-lib.sh"

# 默认触发原因
TRIGGER_REASON="${1:-定时认知刷新}"

# 日志文件
COG_LOG="$SCRIPT_DIR/../memory/cognition-trigger.log"
mkdir -p "$(dirname "$COG_LOG")"

# 防重复: 检查最近5分钟内是否已触发过
if [ -f "$COG_LOG" ]; then
    LAST_TRIGGER=$(tail -1 "$COG_LOG" 2>/dev/null | cut -d'|' -f1)
    NOW_EPOCH=$(date +%s)
    if [ -n "$LAST_TRIGGER" ] && [ "$((NOW_EPOCH - LAST_TRIGGER))" -lt 300 ]; then
        echo "[零-认知触发器] 上次触发在5分钟内，跳过重复触发"
        exit 0
    fi
fi

echo "[零-认知触发器] 触发原因: $TRIGGER_REASON"
echo "[零-认知触发器] 开始认知更新..."

# 调用认知更新脚本
if [ -f "$SCRIPT_DIR/zero-cognition-update.sh" ]; then
    bash "$SCRIPT_DIR/zero-cognition-update.sh" || {
        echo "[零-认知触发器] 认知更新失败，记录故障"
        echo "$(date +%s)|FAIL|$TRIGGER_REASON" >> "$COG_LOG"
        exit 1
    }
else
    echo "[零-认知触发器] 警告: zero-cognition-update.sh 不存在"
fi

# 记录成功触发
echo "$(date +%s)|OK|$TRIGGER_REASON" >> "$COG_LOG"
echo "[零-认知触发器] 认知更新完成"
