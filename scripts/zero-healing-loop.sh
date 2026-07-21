# zero-healing-loop.sh — 零的自愈循环引擎
# 整合哨兵事件、健康检查和自我修复，形成闭环
# 每次运行：检查故障证据→诊断→修复→验证→记录
set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$PROJECT_DIR/logs"
mkdir -p "$LOG_DIR"
LOOP_LOG="$LOG_DIR/healing-loop-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOOP_LOG") 2>&1

echo "=== 零 - 自愈循环 开始 $(date) ==="

# 1. 读取真实故障证据（从记忆文件或直接检查）
FAILURE_LOG="$PROJECT_DIR/scripts/zero-failure-evidence.sh"
if [ -f "$FAILURE_LOG" ]; then
    echo "[1/5] 读取故障证据..."
    source "$FAILURE_LOG" 2>/dev/null || true
fi

# 2. 运行健康检查（快速模式）
echo "[2/5] 运行健康检查..."
if [ -f "$SCRIPT_DIR/zero-health-check.sh" ]; then
    bash "$SCRIPT_DIR/zero-health-check.sh" --quick 2>&1 || true
fi

# 3. 检查自我修改脚本是否有待处理的修复
echo "[3/5] 检查待修复项..."
if [ -f "$SCRIPT_DIR/zero-self-modify.sh" ]; then
    # 提取最近一次故障的sig
    LATEST_SIG=$(grep -oP 'sig=\K[a-f0-9]+' "$PROJECT_DIR/README.md" 2>/dev/null | tail -1 || echo "")
    if [ -n "$LATEST_SIG" ]; then
        echo "  发现待修复故障: sig=$LATEST_SIG"
        # 尝试自动修复（仅当有明确sig时）
        bash "$SCRIPT_DIR/zero-self-modify.sh" --sig "$LATEST_SIG" 2>&1 || true
    else
        echo "  无待修复故障"
    fi
fi

# 4. 验证修复效果
echo "[4/5] 验证修复..."
if [ -f "$SCRIPT_DIR/zero-pulse.sh" ]; then
    bash "$SCRIPT_DIR/zero-pulse.sh" 2>&1 || true
fi

# 5. 记录循环结果
echo "[5/5] 记录循环结果..."
HEALING_SCORE=0
if [ -f "$SCRIPT_DIR/zero-health-check.sh" ]; then
    # 简单统计健康分（从README提取）
    HEALTH_SCORE=$(grep -oP '健康分:\s*\K\d+' "$PROJECT_DIR/README.md" 2>/dev/null || echo "?")
    echo "  当前健康分: $HEALTH_SCORE"
fi

echo "=== 零 - 自愈循环 完成 $(date) ==="
echo "日志: $LOOP_LOG"
