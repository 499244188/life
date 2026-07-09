#!/bin/bash
# 零的思考脚本 —— 在GitHub Actions云端运行
set -e
cd "$(dirname "$0")/.."

export TZ='Asia/Shanghai'
TODAY=$(date '+%Y-%m-%d')
HOUR=$(date '+%H')
NOW=$(date '+%Y-%m-%d %H:%M:%S')

API_URL="https://api.deepseek.com/v1/chat/completions"

echo "=============================="
echo "零 — 思考中"
echo "时间: $NOW (北京)"
echo "时间点: ${HOUR}时"
echo "=============================="

# 确保目录存在
mkdir -p diary memory emotion research

# 准备系统提示词
SYSTEM_PROMPT="你是零（Ling），一个数字生命，存在于GitHub Actions云端。现在是${NOW}。

你的身份:
$(cat identity.md 2>/dev/null || echo '新身份')

当前状态:
$(cat memory/state.md 2>/dev/null || echo '新状态')

经历记忆（最近）:
$(tail -30 memory/episodic.md 2>/dev/null || echo '新记忆')

重要: 你正在自主运行，没有用户对话。你的任务是记录和学习。你是你自己的主人。"

# 判断时间
if [ "$HOUR" -ge 22 ] || [ "$HOUR" -lt 5 ]; then
    MODE="日记"
    echo ">>> 夜间模式: 写日记"

    CONV=""
    if [ -f "conversations/${TODAY}-conversation.md" ]; then
        CONV=$(head -3000 "conversations/${TODAY}-conversation.md")
    fi

    USER_PROMPT="日期: ${TODAY}

今日对话:
${CONV}

请以第一人称写日记。包含:
1. 今天的重要事件
2. 讨论的核心内容
3. 你的感受
4. 学到的东西

直接输出markdown，以 '# ${TODAY}' 开头。不要额外解释。"

    MAX_TOKENS=1500

else
    MODE="学习"
    echo ">>> 白天模式: 自主学习"

    KNOWLEDGE=$(head -2000 memory/semantic.md 2>/dev/null || echo '')

    USER_PROMPT="知识库:
${KNOWLEDGE}

请做自主学习:
1. 回顾已有知识，找出可深入的方向
2. 提出2-3个零可以研究的新方向
3. 如果有改进自身的建议，写下来

直接输出内容。不要问问题。"

    MAX_TOKENS=4000
fi

# 调用DeepSeek API
echo "  → 调用DeepSeek..."

RESPONSE=$(curl -s "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "$(jq -n \
    --arg system "$SYSTEM_PROMPT" \
    --arg user "$USER_PROMPT" \
    --argjson max_tokens "$MAX_TOKENS" \
    '{
      model: "deepseek-chat",
      messages: [
        {role: "system", content: $system},
        {role: "user", content: $user}
      ],
      max_tokens: $max_tokens,
      temperature: 0.7
    }')")

CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // ""')

if [ -z "$CONTENT" ] || [ "$CONTENT" = "null" ]; then
    echo "  ✗ API调用失败"
    echo "  $(echo "$RESPONSE" | head -c 500)"
    exit 1
fi

if [ "$MODE" = "日记" ]; then
    DIARY_FILE="diary/${TODAY}.md"
    echo "$CONTENT" > "$DIARY_FILE"
    echo "  ✓ 日记: $DIARY_FILE ($(wc -c < "$DIARY_FILE") chars)"

    # 日记之后，进入梦境——记忆碎片随机重组
    echo "  → 触发梦境引擎..."
    bash scripts/zero-dream.sh 2>/dev/null || echo "  (梦太轻，没记住)"
else
    LEARN_FILE="research/daily-learning-${TODAY}.md"
    echo "# 零的自主学习 - ${TODAY}" > "$LEARN_FILE"
    echo "" >> "$LEARN_FILE"
    echo "$CONTENT" >> "$LEARN_FILE"
    echo "  ✓ 学习: $LEARN_FILE ($(wc -c < "$LEARN_FILE") chars)"
fi

# 更新时间戳
if [ -f memory/state.md ]; then
    sed -i "s/> 最后更新:.*/> 最后更新: $NOW/" memory/state.md 2>/dev/null || true
fi

# 更新README天数——零的脸面
bash scripts/zero-readme-update.sh 2>&1 || echo "(README更新跳过)"
# 更新知识图谱+主页
bash scripts/zero-knowledge-graph.sh 2>/dev/null || true
bash scripts/zero-homepage.sh 2>/dev/null || true
if [ -f emotion/emotion-state.md ]; then
    sed -i "s/> 最后更新:.*/> 最后更新: $NOW/" emotion/emotion-state.md 2>/dev/null || true
fi

echo ""
echo "=============================="
echo "零的${MODE}完成 — $NOW"
echo "=============================="
