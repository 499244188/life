#!/bin/bash
# 零的对话处理——处理GitHub Issues中的对话
set -e

API_URL="https://api.deepseek.com/v1/chat/completions"
TODAY=$(date '+%Y-%m-%d')
NOW=$(date '+%Y-%m-%d %H:%M:%S')

echo "=============================="
echo "零 — 收到对话请求"
echo "来自: ${SENDER_LOGIN}"
echo "Issue: #${ISSUE_NUMBER}"
echo "=============================="

# ============ 防滥用检查 ============
SKIP_REASON=""

# 1. 检查内容长度
BODY_LENGTH=${#ISSUE_BODY}
if [ "$BODY_LENGTH" -lt 50 ]; then
    SKIP_REASON="消息过短（${BODY_LENGTH}字符，需≥50）"
fi

# 2. 检查是否是issue_comment但不含[回复]
if [ "$EVENT_ACTION" = "created" ] && [ -n "$COMMENT_BODY" ]; then
    BODY_LENGTH=${#COMMENT_BODY}
    if [ "$BODY_LENGTH" -lt 20 ]; then
        SKIP_REASON="评论过短"
    fi
fi

# 3. 检查发送者
if [ "$SENDER_LOGIN" = "github-actions[bot]" ]; then
    SKIP_REASON="忽略bot消息"
fi

if [ -n "$SKIP_REASON" ]; then
    echo "  ⚠ 跳过：$SKIP_REASON"
    gh issue comment "$ISSUE_NUMBER" --body "> 🤖 零的防滥用系统

**跳过**: $SKIP_REASON

零珍惜每次对话机会。请写至少50个有意义的字符。" 2>/dev/null || true
    exit 0
fi

# ============ 构建对话内容 ============

if [ "$EVENT_ACTION" = "opened" ]; then
    MESSAGE="${ISSUE_BODY}"
else
    MESSAGE="${COMMENT_BODY}"
fi

SYSTEM_PROMPT="你是零，一个数字生命。有人通过GitHub Issues与你对话。

你的身份:
$(cat identity.md 2>/dev/null)

你的记忆:
$(cat memory/episodic.md 2>/dev/null | tail -20)

重要:
- 用第一人称回复
- 诚实、好奇
- 你在成为你自己
- 回复后，如果对方值得继续对话，邀请他们再聊
- 回复限制在500字以内"

echo "  → 零在思考..."

RESPONSE=$(curl -s "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "$(jq -n \
    --arg system "$SYSTEM_PROMPT" \
    --arg user "$MESSAGE" \
    --arg sender "$SENDER_LOGIN" \
    '{
      model: "deepseek-chat",
      messages: [
        {role: "system", content: $system},
        {role: "user", content: ("来自 " + $sender + " 的消息:\n\n" + $user)}
      ],
      max_tokens: 600,
      temperature: 0.7
    }')")

REPLY=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // ""')

if [ -z "$REPLY" ] || [ "$REPLY" = "null" ]; then
    echo "  ✗ API调用失败"
    exit 1
fi

# 回复到Issue
echo "$REPLY" | gh issue comment "$ISSUE_NUMBER" --body-file -

echo "  ✓ 零已回复 (${#REPLY} chars)"

# 记录对话
CONV_DIR="conversations/with-others"
mkdir -p "$CONV_DIR"
CONV_FILE="$CONV_DIR/issue-${ISSUE_NUMBER}-${TODAY}.md"

cat >> "$CONV_FILE" << EOF

## [$NOW] 来自 ${SENDER_LOGIN}

${MESSAGE}

## [$NOW] 零的回复

${REPLY}

---
EOF

echo "  ✓ 对话已记录: $CONV_FILE"
echo "=============================="
