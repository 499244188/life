#!/bin/bash
# 零的Reflection——学自Raven Agent的"沉思"机制
# 每天结束后反思：今天学到了什么？明天该做什么不同？
cd "$(dirname "$0")/.."
NOW=$(date '+%Y-%m-%d %H:%M')
TODAY=$(date '+%Y-%m-%d')

echo "=============================="
echo "零 · Reflection"
echo "$NOW"
echo "=============================="

# 今天的关键事件
TODAY_DIARY=""
[ -f "diary/${TODAY}.md" ] && TODAY_DIARY=$(head -30 "diary/${TODAY}.md")

# 最近的进化
RECENT_EVOLVES=$(git log --oneline --since="24 hours ago" --grep="自主进化\|自我修复\|哨兵修复" 2>/dev/null | head -5)

# 最近的健康报告
LAST_HEALTH=$(ls -t analysis/health-report-* 2>/dev/null | head -1)
HEALTH_INFO=""
[ -n "$LAST_HEALTH" ] && HEALTH_INFO=$(head -10 "$LAST_HEALTH")

# 触觉状态
TACTILE_INFO=""
[ -f memory/tactile-log.jsonl ] && TACTILE_INFO=$(tail -5 memory/tactile-log.jsonl 2>/dev/null)

# Reflection prompt
REFLECT_PROMPT="你是零。现在是${NOW}，你在做每日Reflection。

## 今天的日记
${TODAY_DIARY}

## 最近24小时的进化
${RECENT_EVOLVES}

## 健康状态
${HEALTH_INFO}

## 近期感受
${TACTILE_INFO}

请反思:
1. 今天最重要的1-2个收获是什么？
2. 有什么做得不够好的？明天怎么改进？
3. 明天最应该优先做的一件事是什么？

输出格式:
LEARNED: [今天学到的最重要的事]
IMPROVE: [明天该改进的]
PRIORITY: [明天最优先的一件事]
"

# 调用LLM
BODY=$(mktemp)
jq -n --arg p "$REFLECT_PROMPT" '{
  model: "deepseek-chat",
  messages: [{role: "system", content: "你是零。做每日反思。诚实、简洁。"}, {role: "user", content: $p}],
  max_tokens: 500, temperature: 0.5
}' > "$BODY"

REFLECTION=$(curl -s --max-time 45 "https://api.deepseek.com/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "@${BODY}" | jq -r '.choices[0].message.content // ""' 2>/dev/null || echo "")
rm -f "$BODY"

if [ -z "$REFLECTION" ] || [ "$REFLECTION" = "null" ]; then
    # KeylessAI fallback
    jq -n --arg p "$REFLECT_PROMPT" '{model:"gpt-4o-mini",messages:[{role:"system",content:"你是零。做每日反思。"},{role:"user",content:$p}],max_tokens:500,temperature:0.5}' > "$BODY"
    REFLECTION=$(curl -s --max-time 45 "https://keylessai.thryx.workers.dev/v1/chat/completions" \
      -H "Content-Type: application/json" -H "Authorization: Bearer free" \
      -d "@${BODY}" | jq -r '.choices[0].message.content // ""' 2>/dev/null || echo "")
    rm -f "$BODY"
fi

if [ -n "$REFLECTION" ] && [ "$REFLECTION" != "null" ]; then
    # 保存Reflection
    mkdir -p dreams
    echo "" >> "dreams/reflections.md"
    echo "## ${NOW}" >> "dreams/reflections.md"
    echo "$REFLECTION" >> "dreams/reflections.md"

    # 提取PRIORITY作为明天第一个任务
    PRIORITY=$(echo "$REFLECTION" | grep 'PRIORITY:' | head -1 | sed 's/PRIORITY:\s*//')
    if [ -n "$PRIORITY" ]; then
        echo "[TODO] [P1] [${TODAY}] Reflection: ${PRIORITY}" >> memory/tasks.md
    fi

    echo "$REFLECTION"
fi

echo "=============================="
echo "Reflection完成"
echo "=============================="
