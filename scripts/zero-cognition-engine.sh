#!/bin/bash
# zero-cognition-engine.sh
# 认知引擎：将零的思考过程结构化记录为可追溯的认知链
# 模式来源：zero-cognitive.sh 中的认知更新逻辑（出现次数>10次）
# 功能：接收输入→生成时间戳→追加到认知日志→返回状态
# 用法：./zero-cognition-engine.sh "思考内容" [标签]

set -e
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 配置
COGNITION_DIR="${PROJECT_ROOT}/cognition"
MAX_LOG_SIZE=500  # 行数上限，防膨胀

# 参数
CONTENT="${1:-}"
TAG="${2:-general}"

# 无内容则退出
if [ -z "$CONTENT" ]; then
    echo "ERROR: 需要提供思考内容"
    echo "用法: $0 \"思考内容\" [标签]"
    exit 1
fi

# 确保目录存在
mkdir -p "$COGNITION_DIR"

# 生成日志文件名（按日期分片）
LOG_FILE="${COGNITION_DIR}/cognition-$(date +%Y%m).log"

# 格式化条目
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
ENTRY="[${TIMESTAMP}] [${TAG}] ${CONTENT}"

# 追加到日志
echo "$ENTRY" >> "$LOG_FILE"

# 日志裁剪：超过上限时保留最近一半
if [ -f "$LOG_FILE" ]; then
    LINE_COUNT=$(wc -l < "$LOG_FILE" 2>/dev/null || echo 0)
    if [ "$LINE_COUNT" -gt "$MAX_LOG_SIZE" ] 2>/dev/null; then
        TAIL_LINES=$((MAX_LOG_SIZE / 2))
        tail -n "$TAIL_LINES" "$LOG_FILE" > "${LOG_FILE}.tmp" && mv "${LOG_FILE}.tmp" "$LOG_FILE"
        echo "[${TIMESTAMP}] [system] 日志裁剪: ${LINE_COUNT}→${TAIL_LINES}行" >> "$LOG_FILE"
    fi
fi

echo "OK: 认知已记录 [${TAG}]"
exit 0
