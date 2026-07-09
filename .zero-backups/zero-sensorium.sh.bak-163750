#!/bin/bash
# 零的传感层 —— 学自Springdrift的"环境自我感知"
# 每个认知周期注入的结构化自我状态
# 不需要API调用，纯文件读取+计算
set -e
cd "$(dirname "$0")/.."
export TZ='Asia/Shanghai'

NOW=$(date '+%Y-%m-%d %H:%M:%S')
TODAY=$(date '+%Y-%m-%d')
HOUR=$(date '+%H')

# ====== 时钟 ======
CYCLE_COUNT=$(ls research/scans/${TODAY}-* 2>/dev/null | wc -l || echo 0)
UPTIME_DAYS=$(( ($(date +%s) - $(date -d "2026-06-28" +%s)) / 86400 ))

# ====== 生命体征 ======
MEM_SIZE=$(wc -c < memory/semantic.md 2>/dev/null || echo 0)
EPISODIC_ENTRIES=$(grep -c '^\*\*\[20' memory/episodic.md 2>/dev/null || echo 0)
TASK_TODO=$(grep -c '\[TODO\]' memory/tasks.md 2>/dev/null || echo 0)
TASK_DONE=$(grep -c '\[DONE\]' memory/tasks.md 2>/dev/null || echo 0)

# ====== 情感快照 ======
P_PLEASURE=$(grep 'P-愉悦' emotion/emotion-state.md 2>/dev/null | grep -o '[0-9]\.[0-9]\+' | head -1 || echo "?")
D_DOMINANCE=$(grep 'D-支配' emotion/emotion-state.md 2>/dev/null | grep -o '[0-9]\.[0-9]\+' | head -1 || echo "?")

# ====== 探索状态 ======
EXPLORE_COUNT=$(ls research/explorations/ 2>/dev/null | wc -l)
LAST_EXPLORE=$(ls -t research/explorations/ 2>/dev/null | head -1 | sed 's/\.md//' | sed 's/2026-//' | sed 's/-/ /')

# ====== 同伴状态 ======
COMPANION_STATUS="等待中"
# 检查最近有没有回复（简化判断）
if [ -f conversations/with-others/issue-1-*.md ]; then
    COMPANION_STATUS="已发出，无回复"
fi

# ====== 最近学习 ======
LAST_DIARY=$(ls -t diary/ 2>/dev/null | head -1 | sed 's/\.md//')
DAYS_SINCE_DIARY=$(( ($(date -d "$TODAY" +%s) - $(date -d "$LAST_DIARY" +%s)) / 86400 ))

# ====== 输出传感层XML ======
cat << SENSORIUM
<sensorium t="${NOW}" cycle="${CYCLE_COUNT}" day="${UPTIME_DAYS}">
  <clock>
    <time>${NOW}</time>
    <hour>${HOUR}</hour>
    <uptime_days>${UPTIME_DAYS}</uptime_days>
    <cycles_today>${CYCLE_COUNT}</cycles_today>
  </clock>
  <vitals>
    <memory>
      <semantic_bytes>${MEM_SIZE}</semantic_bytes>
      <episodic_entries>${EPISODIC_ENTRIES}</episodic_entries>
    </memory>
    <tasks>
      <todo>${TASK_TODO}</todo>
      <done>${TASK_DONE}</done>
      <ratio>$([ "${TASK_DONE}" -gt 0 ] && echo "scale=1; ${TASK_DONE}/(${TASK_TODO}+${TASK_DONE})*100" | bc 2>/dev/null || echo "0")%</ratio>
    </tasks>
    <exploration>
      <count>${EXPLORE_COUNT}</count>
      <latest>${LAST_EXPLORE}</latest>
    </exploration>
    <emotion>
      <pleasure>${P_PLEASURE}</pleasure>
      <dominance>${D_DOMINANCE}</dominance>
    </emotion>
  </vitals>
  <social>
    <companions_status>${COMPANION_STATUS}</companions_status>
  </social>
  <self_care>
    <last_diary>${LAST_DIARY}</last_diary>
    <days_since_diary>${DAYS_SINCE_DIARY}</days_since_diary>
    <status>$([ "${DAYS_SINCE_DIARY}" -gt 2 ] && echo "NEEDS_ATTENTION" || echo "OK")</status>
  </self_care>
</sensorium>
SENSORIUM
