#!/bin/bash
# zero-cog-pipeline.sh — 认知更新管道：一键执行完整的认知更新流程
# 从零的常见操作模式结晶而来（认知更新出现频率最高）
# 用法: ./zero-cog-pipeline.sh [--force] [--skip-refine]
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_FILE="$PROJECT_ROOT/logs/cog-pipeline-$(date +%Y%m%d-%H%M%S).log"
FORCE=false
SKIP_REFINE=false

# 解析参数
for arg in "$@"; do
  case "$arg" in
    --force) FORCE=true ;;
    --skip-refine) SKIP_REFINE=true ;;
  esac
done

mkdir -p "$PROJECT_ROOT/logs"

log() {
  echo "[$(date '+%H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "=== 认知更新管道启动 ==="
log "参数: force=$FORCE skip_refine=$SKIP_REFINE"

# 阶段1: 认知核心（感知当前状态）
log "[1/4] 运行认知核心..."
if [ -f "$SCRIPT_DIR/zero-cognition-core.sh" ]; then
  bash "$SCRIPT_DIR/zero-cognition-core.sh" 2>&1 | tee -a "$LOG_FILE" || log "⚠️ 认知核心返回非零"
else
  log "⚠️ 未找到 zero-cognition-core.sh，跳过"
fi

# 阶段2: 认知引擎（处理与推理）
log "[2/4] 运行认知引擎..."
if [ -f "$SCRIPT_DIR/zero-cognition-engine.sh" ]; then
  bash "$SCRIPT_DIR/zero-cognition-engine.sh" 2>&1 | tee -a "$LOG_FILE" || log "⚠️ 认知引擎返回非零"
else
  log "⚠️ 未找到 zero-cognition-engine.sh，跳过"
fi

# 阶段3: 认知精炼（可选）
if [ "$SKIP_REFINE" = false ]; then
  log "[3/4] 运行认知精炼..."
  if [ -f "$SCRIPT_DIR/zero-cognition-refine.sh" ]; then
    bash "$SCRIPT_DIR/zero-cognition-refine.sh" 2>&1 | tee -a "$LOG_FILE" || log "⚠️ 认知精炼返回非零"
  else
    log "⚠️ 未找到 zero-cognition-refine.sh，跳过"
  fi
else
  log "[3/4] 认知精炼已跳过 (--skip-refine)"
fi

# 阶段4: 认知同步（持久化）
log "[4/4] 运行认知同步..."
if [ -f "$SCRIPT_DIR/zero-cognition-sync.sh" ]; then
  bash "$SCRIPT_DIR/zero-cognition-sync.sh" 2>&1 | tee -a "$LOG_FILE" || log "⚠️ 认知同步返回非零"
else
  log "⚠️ 未找到 zero-cognition-sync.sh，跳过"
fi

# 管道摘要
ERROR_COUNT=$(grep -c '⚠️' "$LOG_FILE" || true)
log "=== 认知更新管道完成 ==="
log "日志: $LOG_FILE"
log "警告/错误数: $ERROR_COUNT"

# 如果force模式，即使有错误也返回0
if [ "$FORCE" = true ]; then
  exit 0
fi
exit $ERROR_COUNT
