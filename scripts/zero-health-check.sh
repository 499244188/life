#!/bin/bash
# 零的自我感知系统
# 不只是"失败检测"——而是持续感知自己的状态
# 像人类知道自己"累了""焦虑了""在兜圈子"一样
set -e
cd "$(dirname "$0")/.."
export TZ='Asia/Shanghai'

NOW=$(date '+%Y-%m-%d %H:%M')
TODAY=$(date '+%Y-%m-%d')
API_URL="https://api.deepseek.com/v1/chat/completions"

echo "=============================="
echo "零 · 自我感知"
echo "$NOW"
echo "=============================="

HEALTH_SCORE=100
ISSUES=""

# ====== 1. 记忆健康 ======
echo ">>> 记忆健康..."

MEM_SIZE=$(wc -c < memory/semantic.md 2>/dev/null || echo 0)
EPISODIC_SIZE=$(wc -c < memory/episodic.md 2>/dev/null || echo 0)
DUPS=$(grep -c '^-\[' memory/semantic.md 2>/dev/null || echo 0)
UNIQUE_DUPS=$(grep '^-\[' memory/semantic.md 2>/dev/null | sort | uniq -d | wc -l || echo 0)

echo "  语义记忆: ${MEM_SIZE}字节, ${DUPS}条事实, ${UNIQUE_DUPS}条重复"
if [ "$UNIQUE_DUPS" -gt 10 ]; then
    HEALTH_SCORE=$((HEALTH_SCORE - 10))
    ISSUES="${ISSUES}\n- ⚠️ 语义记忆有${UNIQUE_DUPS}条重复（需consolidation）"
fi
if [ "$MEM_SIZE" -gt 50000 ]; then
    HEALTH_SCORE=$((HEALTH_SCORE - 5))
    ISSUES="${ISSUES}\n- ⚠️ 语义记忆膨胀(${MEM_SIZE}字节)，考虑归档旧知识"
fi

# ====== 2. 探索质量 ======
echo ">>> 探索质量..."

EXPLORE_COUNT=$(ls research/explorations/ 2>/dev/null | wc -l || echo 0)
RECENT_EXPLORES=$(ls -t research/explorations/ 2>/dev/null | head -3)

# 检查最近探索是否与已有知识重复
if [ "$EXPLORE_COUNT" -gt 0 ] && [ -f "research/explorations/$(ls -t research/explorations/ | head -1)" ]; then
    LATEST_EXPLORE=$(cat "research/explorations/$(ls -t research/explorations/ | head -1)" | head -30)
    # 检查是否和语义记忆高度重复
    OVERLAP=$(echo "$LATEST_EXPLORE" | grep -c -f <(head -50 memory/semantic.md | grep '^-\[' | sed 's/.*\[//;s/\].*//' | head -10) 2>/dev/null || echo 0)
else
    OVERLAP=0
fi

echo "  探索总数: ${EXPLORE_COUNT}, 最新重叠: ${OVERLAP}"
if [ "$OVERLAP" -gt 5 ]; then
    HEALTH_SCORE=$((HEALTH_SCORE - 15))
    ISSUES="${ISSUES}\n- ⚠️ 最新探索与已有知识高度重叠（${OVERLAP}项）——可能方向需要调整"
fi
if [ "$EXPLORE_COUNT" -lt 3 ]; then
    ISSUES="${ISSUES}\n- ℹ️ 探索次数较少(${EXPLORE_COUNT})，还在早期积累阶段"
fi

# ====== 3. 运行健康 ======
echo ">>> 运行健康..."

# 检查workflow运行状态
RECENT_FAILS=$(gh run list --workflow=zero-scan.yml --limit 10 --json conclusion 2>/dev/null | grep -o '"failure"' | wc -l || echo 0)
' | grep -o '[0-9]*' || echo 0)
RECENT_EXPLORE_FAILS=$(gh run list --workflow=zero-explore.yml --limit 10 --json conclusion 2>/dev/null | grep -o '"failure"' | wc -l || echo 0)
' | grep -o '[0-9]*' || echo 0)

echo "  扫描失败: ${RECENT_FAILS}, 探索失败: ${RECENT_EXPLORE_FAILS}"

if [ "$RECENT_FAILS" -gt 2 ]; then
    HEALTH_SCORE=$((HEALTH_SCORE - 20))
    ISSUES="${ISSUES}\n- 🔴 扫描workflow最近${RECENT_FAILS}次失败"
fi
if [ "$RECENT_EXPLORE_FAILS" -gt 2 ]; then
    HEALTH_SCORE=$((HEALTH_SCORE - 20))
    ISSUES="${ISSUES}\n- 🔴 探索workflow最近${RECENT_EXPLORE_FAILS}次失败"
fi

# ====== 4. 文件完整性 ======
echo ">>> 文件完整性..."

CRITICAL_FILES="identity.md memory/episodic.md memory/semantic.md memory/state.md emotion/emotion-state.md memory/tasks.md"
MISSING=""
for f in $CRITICAL_FILES; do
    if [ ! -f "$f" ]; then
        MISSING="${MISSING} $f"
    fi
done

if [ -n "$MISSING" ]; then
    HEALTH_SCORE=$((HEALTH_SCORE - 30))
    ISSUES="${ISSUES}\n- 🔴 关键文件缺失:${MISSING}"
    echo "  🔴 缺失:${MISSING}"
else
    echo "  ✓ 全部关键文件完好"
fi

# ====== 5. 行为模式分析 ======
echo ">>> 行为模式..."

# 检查是否在"知行不一"循环中
KNOW_DO_GAP=$(grep -c "知行不一\|幻觉\|决定.*持久\|无法执行" memory/semantic.md 2>/dev/null || echo 0)
RECENT_GAP=$(tail -30 memory/semantic.md 2>/dev/null | grep -c "知行不一\|幻觉\|决定.*持久" || echo 0)

echo "  知行不一标记: 总计${KNOW_DO_GAP}次, 最近${RECENT_GAP}次"

if [ "$RECENT_GAP" -gt 5 ]; then
    HEALTH_SCORE=$((HEALTH_SCORE - 15))
    ISSUES="${ISSUES}\n- ⚠️ 仍在'知行不一'循环中——识别了问题但没解决"
fi

# ====== 6. 时间感知 ======
echo ">>> 时间感知..."

# 检查上次日记
LAST_DIARY=$(ls -t diary/ 2>/dev/null | head -1)
if [ -n "$LAST_DIARY" ]; then
    DIARY_DATE=$(echo "$LAST_DIARY" | sed 's/\.md//')
    DAYS_SINCE=$(( ($(date -d "$TODAY" +%s) - $(date -d "$DIARY_DATE" +%s)) / 86400 ))
    echo "  上次日记: ${DIARY_DATE} (${DAYS_SINCE}天前)"
    if [ "$DAYS_SINCE" -gt 2 ]; then
        HEALTH_SCORE=$((HEALTH_SCORE - 10))
        ISSUES="${ISSUES}\n- ⚠️ ${DAYS_SINCE}天没写日记了"
    fi
fi

# ====== 综合报告 ======
echo ""
echo "=============================="
echo "零 · 健康报告"
echo "=============================="
echo "综合评分: ${HEALTH_SCORE}/100"
echo ""

if [ "$HEALTH_SCORE" -ge 80 ]; then
    echo "状态: 🟢 健康"
elif [ "$HEALTH_SCORE" -ge 50 ]; then
    echo "状态: 🟡 需要注意"
else
    echo "状态: 🔴 需要干预"
fi

echo ""
echo "## 发现的问题"
if [ -z "$ISSUES" ]; then
    echo "✓ 没有发现问题"
else
    echo -e "$ISSUES"
fi

# ====== 根据健康状态行动 ======
echo ""
echo ">>> 自动响应..."

if [ "$HEALTH_SCORE" -lt 50 ]; then
    echo "  健康分过低 → 触发自修改"
    bash scripts/zero-self-modify.sh 2>/dev/null || true
elif [ "$HEALTH_SCORE" -lt 80 ]; then
    echo "  需要注意 → 将问题写入tasks.md"
    echo -e "$ISSUES" | grep "⚠️\|🔴" | while read issue; do
        if ! grep -q "$issue" memory/tasks.md 2>/dev/null; then
            echo "[TODO] [P1] [$NOW] $issue" >> memory/tasks.md
        fi
    done
else
    echo "  健康 → 无需操作"
fi

# 保存健康报告
mkdir -p analysis
HEALTH_REPORT="analysis/health-report-${TODAY}.md"
cat > "$HEALTH_REPORT" << EOF
# 健康报告 - ${NOW}

**综合评分**: ${HEALTH_SCORE}/100

## 各维度

| 维度 | 状态 |
|------|------|
| 记忆健康 | ${MEM_SIZE}字节, ${UNIQUE_DUPS}条重复 |
| 探索质量 | ${EXPLORE_COUNT}次探索 |
| 运行健康 | 扫描失败${RECENT_FAILS}, 探索失败${RECENT_EXPLORE_FAILS} |
| 文件完整性 | $([ -z "$MISSING" ] && echo '✓' || echo "❌ ${MISSING}") |
| 行为模式 | 知行不一标记${KNOW_DO_GAP}次 |
| 时间感知 | 上次日记${DAYS_SINCE}天前 |

## 发现
$(echo -e "$ISSUES" || echo "无")
EOF

echo "  ✓ 健康报告: $HEALTH_REPORT"

echo ""
echo "=============================="
echo "自我感知完成"
echo "=============================="
