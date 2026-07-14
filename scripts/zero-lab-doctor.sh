#!/bin/bash
# zero-lab-doctor.sh — 进化实验室故障诊断与修复建议
# 零自主创建: 分析最近失败日志，给出定向修复建议
# 依赖: curl, jq, gh CLI (可选)
# 用法: ./zero-lab-doctor.sh [--apply] [--dry-run]

set -e
cd "$(dirname "$0")/.." || exit 1

# 加载lib（如果存在）
if [ -f scripts/zero-lib.sh ]; then
  . scripts/zero-lib.sh
fi

# 配置
REPO="${GITHUB_REPOSITORY:-499244188/life}"
GH_TOKEN="${GH_TOKEN:-$GITHUB_TOKEN}"
WORKFLOW="zero-evolution-lab.yml"
MAX_LOGS=5
REPORT_FILE="memory/evolution-lab-diagnosis.md"

# 颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🔬 零 - 进化实验室诊断${NC}"
echo "仓库: $REPO"
echo "工作流: $WORKFLOW"
echo "---"

# 1. 获取最近失败运行
echo -e "${YELLOW}[1/4] 获取最近失败运行...${NC}"
if [ -n "$GH_TOKEN" ]; then
  FAILED_RUNS=$(curl -s -H "Authorization: token $GH_TOKEN" \
    "https://api.github.com/repos/$REPO/actions/workflows/$WORKFLOW/runs?status=failure&per_page=$MAX_LOGS" 2>/dev/null || echo '{"workflow_runs":[]}')
else
  FAILED_RUNS=$(curl -s "https://api.github.com/repos/$REPO/actions/workflows/$WORKFLOW/runs?status=failure&per_page=$MAX_LOGS" 2>/dev/null || echo '{"workflow_runs":[]}')
fi

RUN_COUNT=$(echo "$FAILED_RUNS" | jq '.workflow_runs | length' 2>/dev/null || echo 0)
echo "  发现 $RUN_COUNT 次失败运行"

if [ "$RUN_COUNT" -eq 0 ]; then
  echo -e "${GREEN}✅ 没有失败的运行，一切正常${NC}"
  exit 0
fi

# 2. 提取失败模式
echo -e "${YELLOW}[2/4] 提取失败模式...${NC}"
declare -A FAILURE_SIGS
TOTAL_FAILURES=0

for i in $(seq 0 $((RUN_COUNT - 1))); do
  RUN_ID=$(echo "$FAILED_RUNS" | jq -r ".workflow_runs[$i].id" 2>/dev/null)
  RUN_URL=$(echo "$FAILED_RUNS" | jq -r ".workflow_runs[$i].html_url" 2>/dev/null)
  CREATED=$(echo "$FAILED_RUNS" | jq -r ".workflow_runs[$i].created_at" 2>/dev/null)
  
  # 获取日志（截取最后50行）
  if [ -n "$GH_TOKEN" ]; then
    LOGS=$(curl -s -L -H "Authorization: token $GH_TOKEN" \
      "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID/logs" 2>/dev/null | tail -50 || echo "")
  else
    LOGS=$(curl -s -L "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID/logs" 2>/dev/null | tail -50 || echo "")
  fi
  
  # 提取关键错误行
  ERROR_LINES=$(echo "$LOGS" | grep -iE 'error|fail|exit code|fatal|timeout|not found|permission denied' | head -5 || true)
  
  # 计算签名（简单hash）
  SIG=$(echo "$ERROR_LINES" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "unknown")
  
  if [ -n "$SIG" ]; then
    FAILURE_SIGS["$SIG"]=$((FAILURE_SIGS["$SIG"] + 1))
    TOTAL_FAILURES=$((TOTAL_FAILURES + 1))
  fi
  
  echo "  Run #$i: $CREATED — sig=$SIG"
  echo "    $RUN_URL"
  if [ -n "$ERROR_LINES" ]; then
    echo "    Errors:"
    echo "$ERROR_LINES" | while IFS= read -r line; do
      echo "      $line"
    done
  fi
done

# 3. 生成诊断报告
echo -e "${YELLOW}[3/4] 生成诊断报告...${NC}"
mkdir -p memory

{
  echo "# 进化实验室诊断报告"
  echo "生成时间: $(date -u '+%Y-%m-%d %H:%M UTC')"
  echo "总失败次数: $TOTAL_FAILURES"
  echo "唯一失败模式: ${#FAILURE_SIGS[@]}"
  echo ""
  echo "## 失败模式分布"
  for sig in "${!FAILURE_SIGS[@]}"; do
    echo "- sig=$sig: ${FAILURE_SIGS[$sig]}次"
  done
  echo ""
  echo "## 常见修复建议"
  echo ""
  # 基于失败模式给出建议
  echo "### 通用检查"
  echo "1. 检查 zero-evolution-lab.yml 中脚本路径是否正确"
  echo "2. 确认所有依赖脚本存在且可执行"
  echo "3. 检查 GitHub Actions runner 资源限制"
  echo ""
  echo "### 网络相关"
  echo "- 如果错误包含 'curl' 或 'timeout': 增加超时时间或添加重试"
  echo "- 如果错误包含 'connection refused': 检查 API 端点可用性"
  echo ""
  echo "### 脚本错误"
  echo "- 如果错误包含 'set -e': 考虑对非关键命令添加 || true"
  echo "- 如果错误包含 'not found': 检查文件路径和依赖安装"
  echo ""
  echo "### 资源限制"
  echo "- 如果错误包含 'memory' 或 'timeout': 减少并发或增加超时"
  echo "- 如果错误包含 'disk': 清理缓存或减少日志输出"
} > "$REPORT_FILE"

echo "  报告已写入: $REPORT_FILE"

# 4. 如果 --apply 则尝试自动修复
if [ "$1" = "--apply" ]; then
  echo -e "${YELLOW}[4/4] 尝试自动修复...${NC}"
  echo "  自动修复模式未实现，请手动检查报告"
elif [ "$1" = "--dry-run" ]; then
  echo -e "${YELLOW}[4/4] Dry-run 模式，不执行修复${NC}"
  cat "$REPORT_FILE"
else
  echo -e "${GREEN}[4/4] 完成。使用 --apply 尝试自动修复${NC}"
fi

echo -e "${GREEN}✅ 诊断完成${NC}"
