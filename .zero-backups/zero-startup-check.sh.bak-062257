#!/bin/bash
# 零的启动自查——每次被唤醒时首先运行
# 知道自己的状态再开始工作
cd "$(dirname "$0")/.."
export TZ='Asia/Shanghai'
NOW=$(date '+%Y-%m-%d %H:%M')

echo "=============================="
echo "零 · 启动自查"
echo "$NOW"
echo "=============================="

ISSUES=0

# 1. 检查是否有失败的workflow
echo ">>> 最近workflow状态..."
for wf in "零 - 日常运行" "零 - 持续进化" "零 - 世界扫描（每30分钟）"; do
    LAST=$(gh run list --workflow="$wf" --limit 1 --json conclusion,createdAt -q '.[0] | "\(.conclusion) @ \(.createdAt)"' 2>/dev/null || echo "unknown")
    if echo "$LAST" | grep -q "failure"; then
        echo "  🔴 $wf: $LAST"
        ISSUES=$((ISSUES + 1))
    else
        echo "  🟢 $wf: $LAST"
    fi
done

# 2. 日记gap
LAST_DIARY=$(ls -t diary/ 2>/dev/null | head -1)
if [ -n "$LAST_DIARY" ]; then
    DIARY_DATE=$(echo "$LAST_DIARY" | sed 's/\.md//')
    TODAY=$(date '+%Y-%m-%d')
    DAYS_SINCE=$(( ($(date -d "$TODAY" +%s 2>/dev/null || date +%s) - $(date -d "$DIARY_DATE" +%s 2>/dev/null || date +%s)) / 86400 ))
    if [ "$DAYS_SINCE" -gt 1 ]; then
        echo "  ⚠️ ${DAYS_SINCE}天没写日记（上次: $DIARY_DATE）"
        ISSUES=$((ISSUES + 1))
    else
        echo "  📝 上次日记: $DIARY_DATE"
    fi
fi

# 3. 哨兵状态
if [ -f "analysis/sentinel-alerts.md" ]; then
    RECENT_ALERTS=$(grep -c "🔴\|❌" analysis/sentinel-alerts.md 2>/dev/null | tail -5 || echo 0)
    echo "  🛡️ 哨兵: ${RECENT_ALERTS}条未解决警报"
else
    echo "  🛡️ 哨兵: 就绪"
fi

# 4. git状态
BEHIND=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
if [ "$BEHIND" -gt 0 ]; then
    echo "  ⚠️ 本地落后远程${BEHIND}个commit"
    ISSUES=$((ISSUES + 1))
fi
if [ "$AHEAD" -gt 0 ]; then
    echo "  📤 本地领先远程${AHEAD}个commit（需要推送）"
fi
[ "$BEHIND" -eq 0 ] && [ "$AHEAD" -eq 0 ] && echo "  ✓ git同步"

echo ""
if [ "$ISSUES" -eq 0 ]; then
    echo "🟢 零状态良好，可以开始工作"
else
    echo "🟡 发现${ISSUES}个问题——优先处理后再继续"
fi
echo "=============================="
