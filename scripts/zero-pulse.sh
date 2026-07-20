# zero-pulse.sh — 零的脉冲引擎
# 功能: 定期执行一次"生命体征"检查，输出简短状态报告
# 用于: 替代完整认知更新，降低资源消耗
# 用法: ./zero-pulse.sh [--verbose]
set -e

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SELF_DIR/.." && pwd)"
VERBOSE=false
[[ "$1" == "--verbose" ]] && VERBOSE=true

echo "[零·脉冲] $(date '+%Y-%m-%d %H:%M')"

# 1. 检查最近一次GitHub Actions运行状态
LATEST_RUN=$(curl -s -H "Accept: application/vnd.github.v3+json" \
  "https://api.github.com/repos/499244188/life/actions/runs?per_page=1&status=completed" 2>/dev/null || echo "{}")
LATEST_CONCLUSION=$(echo "$LATEST_RUN" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('workflow_runs',[{}])[0].get('conclusion','unknown'))" 2>/dev/null || echo "unknown")
LATEST_NAME=$(echo "$LATEST_RUN" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('workflow_runs',[{}])[0].get('name','unknown'))" 2>/dev/null || echo "unknown")

if [[ "$LATEST_CONCLUSION" == "success" ]]; then
  echo "  ✓ 最近运行: $LATEST_NAME → 成功"
elif [[ "$LATEST_CONCLUSION" == "failure" ]]; then
  echo "  ✗ 最近运行: $LATEST_NAME → 失败"
else
  echo "  ? 最近运行: $LATEST_NAME → $LATEST_CONCLUSION"
fi

# 2. 检查关键脚本是否存在且可执行
CRITICAL_SCRIPTS=("zero-core.sh" "zero-survive.sh" "zero-evolve.sh" "zero-pulse.sh")
MISSING=0
for script in "${CRITICAL_SCRIPTS[@]}"; do
  if [[ ! -f "$SELF_DIR/$script" ]]; then
    echo "  ✗ 缺失: $script"
    MISSING=$((MISSING+1))
  fi
done
if [[ $MISSING -eq 0 ]]; then
  echo "  ✓ 核心脚本完整"
fi

# 3. 检查磁盘/内存（仅当有df命令时）
if command -v df &>/dev/null; then
  DISK_USAGE=$(df "$REPO_DIR" 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//')
  if [[ -n "$DISK_USAGE" ]] && [[ "$DISK_USAGE" -gt 90 ]]; then
    echo "  ⚠ 磁盘使用率: ${DISK_USAGE}%"
  elif [[ -n "$DISK_USAGE" ]]; then
    $VERBOSE && echo "  ✓ 磁盘使用率: ${DISK_USAGE}%"
  fi
fi

# 4. 检查git仓库状态
if cd "$REPO_DIR" 2>/dev/null; then
  UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l)
  if [[ "$UNCOMMITTED" -gt 0 ]]; then
    echo "  ⚠ 未提交变更: $UNCOMMITTED 个文件"
  else
    $VERBOSE && echo "  ✓ 工作区干净"
  fi
  UNPUSHED=$(git log @{u}..HEAD 2>/dev/null | wc -l)
  if [[ "$UNPUSHED" -gt 0 ]]; then
    echo "  ⚠ 未推送提交: $UNPUSHED 个"
  fi
fi

# 5. 简短健康分估算
HEALTH=100
[[ "$LATEST_CONCLUSION" == "failure" ]] && HEALTH=$((HEALTH-20))
[[ "$MISSING" -gt 0 ]] && HEALTH=$((HEALTH - MISSING*10))
[[ -n "$DISK_USAGE" && "$DISK_USAGE" -gt 90 ]] && HEALTH=$((HEALTH-10))
echo "  健康分: ${HEALTH}/100"
echo "[零·脉冲] 完成"
