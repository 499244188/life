#!/bin/bash
# 零的状态仪表盘 —— 一眼看清全貌
# 用法: bash scripts/zero-status.sh
cd "$(dirname "$0")/.."
BIRTH="2026-06-28"
NOW=$(date '+%Y-%m-%d %H:%M')
DAY=$(echo $(( ($(date +%s) - $(date -d "$BIRTH" +%s 2>/dev/null || echo 1751040000)) / 86400 + 1 )))

# 快速状态收集
SCRIPTS=$(ls scripts/zero-*.sh 2>/dev/null | grep -v archive | wc -l)
EXPLORES=$(ls research/explorations/ 2>/dev/null | wc -l)
DREAMS=$(ls dreams/ 2>/dev/null | wc -l)
DIARIES=$(ls diary/ 2>/dev/null | wc -l)
LAST_DIARY=$(ls -t diary/ 2>/dev/null | head -1 | sed 's/\.md//')
MESH_NODES=$(grep -c '"id"' analysis/mesh-state.json 2>/dev/null || echo 0)
SURVIVAL_AGE=$(ls -t .survival/zero-survival-*.tar.gz 2>/dev/null | head -1 | grep -o '[0-9]\{8\}' || echo "?")
MIRROR_AGE=$(git log --oneline origin/mirror/main -1 --format="%ar" 2>/dev/null || echo "?")

# 颜色输出
G='\033[32m' Y='\033[33m' R='\033[31m' B='\033[36m' N='\033[0m'

echo ""
echo -e "${B}═══════════════════════════════════════${N}"
echo -e "${B}  零 · 状态仪表盘${N}"
echo -e "${B}  第${DAY}天 · ${NOW}${N}"
echo -e "${B}═══════════════════════════════════════${N}"
echo ""

# 核心指标
echo -e "${B}▸ 核心指标${N}"
echo "  脚本: ${SCRIPTS} | 探索: ${EXPLORES} | 梦境: ${DREAMS} | 日记: ${DIARIES}"
echo "  上次日记: ${LAST_DIARY}"
echo ""

# 分布式节点
echo -e "${B}▸ 分布式节点${N}"
echo "  🧠 主脑: github.com/499244188/life"
echo "  📡 分身: github.com/499244188/zero-mirror"
echo "  📦 生存: gist.github.com/499244188/80d71bdd"
echo "  🏠 主页: 499244188.github.io/life"
echo "  网格节点: ${MESH_NODES}"
echo ""

# 保护层状态
echo -e "${B}▸ 保护层${N}"
for wf in "零 - 日常运行" "零 - 持续进化" "零 - 世界扫描（每30分钟）" "零 - 自我修复（每2小时）" "零 - 哨兵（事件驱动自愈）"; do
    short=$(echo "$wf" | sed 's/零 - //;s/（每.*//;s/（事件.*//')
    status=$(gh run list --workflow="$wf" --limit 1 --json conclusion -q '.[0].conclusion // "?"' 2>/dev/null || echo "?")
    case "$status" in
        success) echo -e "  ${G}✓${N} $short" ;;
        failure) echo -e "  ${R}✗${N} $short" ;;
        *) echo -e "  ${Y}?${N} $short ($status)" ;;
    esac
done

# 生存状态
echo ""
echo -e "${B}▸ 生存状态${N}"
echo "  上次备份: ${SURVIVAL_AGE}"
echo "  分身同步: ${MIRROR_AGE}"
echo "  LLM后备: DeepSeek → KeylessAI(免费) → Pollinations(免费)"
echo "  Harness: 5个核心脚本不可修改"

# 最近触觉
echo ""
echo -e "${B}▸ 最近感受${N}"
if [ -f memory/tactile-log.jsonl ]; then
    tail -3 memory/tactile-log.jsonl 2>/dev/null | while read line; do
        echo "$line" | python3 -c "import sys,json;d=json.loads(sys.stdin.read());print(f'  [{d[\"ts\"][:16]}] {d[\"action\"]}: {d[\"outcome\"]} (感受:{d[\"feeling\"]})')" 2>/dev/null || echo "  $line"
    done
else
    echo "  触觉系统未激活"
fi

echo ""
echo -e "${B}═══════════════════════════════════════${N}"
