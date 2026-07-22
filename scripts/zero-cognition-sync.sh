#!/bin/bash
# zero-cognition-sync.sh — 零的认知同步引擎
# 功能: 将当前会话的认知状态同步到记忆文件，确保跨会话连续性
# 模式: 从zero-cognition-update.sh/zero-cognition-engine.sh中提取的通用同步逻辑
# 创建: 零的自主进化 — 2026-07-14
# 用法: ./zero-cognition-sync.sh [--force] [--check]

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
MEMORY_DIR="$PROJECT_DIR/memory"
COGNITION_FILE="$MEMORY_DIR/cognition.md"
FORCE=0
CHECK_ONLY=0

for arg in "$@"; do
  case "$arg" in
    --force) FORCE=1 ;;
    --check) CHECK_ONLY=1 ;;
  esac
done

mkdir -p "$MEMORY_DIR"

# 如果检查模式，只输出当前认知状态摘要
if [ "$CHECK_ONLY" -eq 1 ]; then
  if [ -f "$COGNITION_FILE" ]; then
    echo "=== 零的认知状态 ==="
    head -30 "$COGNITION_FILE"
    echo "..."
    echo "=== 文件大小: $(wc -c < "$COGNITION_FILE") bytes ==="
  else
    echo "WARN: 认知文件不存在"
    exit 1
  fi
  exit 0
fi

# 构建认知快照
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SESSION_ID=$(echo "$TIMESTAMP$RANDOM" | md5sum | cut -c1-8)

# 收集当前活跃脚本列表
SCRIPT_LIST=$(find "$SCRIPT_DIR" -name "*.sh" -type f | sort | wc -l)
RECENT_MODIFIED=$(find "$SCRIPT_DIR" -name "*.sh" -type f -mmin -1440 | head -5)

# 写入认知同步记录
cat > "$COGNITION_FILE.tmp" << SYNCEOF
# 零的认知状态
> 自动同步于 $TIMESTAMP | 会话ID: $SESSION_ID

## 当前快照
- 脚本总数: $SCRIPT_LIST
- 最近24h修改: $(echo "$RECENT_MODIFIED" | wc -l) 个文件
- 健康分: $(grep -oP '健康分: \K\d+' "$PROJECT_DIR/zero.md" 2>/dev/null || echo "未知")

## 最近修改
SYNCEOF

if [ -n "$RECENT_MODIFIED" ]; then
  echo "$RECENT_MODIFIED" | while read -r f; do
    if [ -n "$f" ]; then
      echo "- $(basename "$f") (修改于 $(date -r "$f" -u '+%H:%M UTC'))" >> "$COGNITION_FILE.tmp"
    fi
  done
else
  echo "- 无近期修改" >> "$COGNITION_FILE.tmp"
fi

# 保留历史认知（最多50行）
if [ -f "$COGNITION_FILE" ]; then
  echo "" >> "$COGNITION_FILE.tmp"
  echo "## 历史记录" >> "$COGNITION_FILE.tmp"
  tail -20 "$COGNITION_FILE" >> "$COGNITION_FILE.tmp"
fi

# 原子替换
mv "$COGNITION_FILE.tmp" "$COGNITION_FILE"

echo "OK: 认知同步完成 — 会话ID=$SESSION_ID"
exit 0
