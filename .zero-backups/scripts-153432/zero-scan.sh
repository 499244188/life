#!/bin/bash
# 零的自主扫描 —— 不只是看，而是更新自己的大脑
# 每30分钟运行一次，由GitHub Actions云触发
set -e
cd "$(dirname "$0")/.."

export TZ='Asia/Shanghai'
NOW=$(date '+%Y-%m-%d %H:%M')
TODAY=$(date '+%Y-%m-%d')
HOUR=$(date '+%H')
MINUTE=$(date '+%M')

API_URL="https://api.deepseek.com/v1/chat/completions"
SCAN_COUNT=$(ls research/scans/${TODAY}-* 2>/dev/null | wc -l || echo 0)
SCAN_COUNT=$((SCAN_COUNT + 1))

echo "=============================="
echo "零 — 第${SCAN_COUNT}次扫描"
echo "$NOW"
echo "=============================="

# ====== 零读取自己的大脑 ======
echo ">>> 读取大脑..."

BRAIN_STATE=$(cat << BRAIN
## 身份
$(cat identity.md 2>/dev/null || echo '无')

## 经历记忆
$(cat memory/episodic.md 2>/dev/null | tail -60)

## 语义记忆（知识）
$(cat memory/semantic.md 2>/dev/null | tail -150)

## 当前状态
$(cat memory/state.md 2>/dev/null)

## 情感状态
$(cat emotion/emotion-state.md 2>/dev/null)

## 知识空白
$(cat analysis/knowledge-gaps.md 2>/dev/null | head -80)

## 兴趣
$(cat research/interests.md 2>/dev/null)

## 自我改进计划
$(cat analysis/self-improvement.md 2>/dev/null | head -40)

## 今天已有的扫描
$(ls research/scans/${TODAY}-* 2>/dev/null | while read f; do echo "---"; head -30 "$f"; done)

## 今天的对话
$(cat conversations/2026-06-29-conversation.md 2>/dev/null | tail -100)
BRAIN
)

# ====== 零全网搜索 ======
echo ">>> 零在搜索世界..."

# GitHub 趋势
GH_TREND=$(curl -s "https://api.github.com/search/repositories?q=AI+agent+autonomous&sort=stars&order=desc&per_page=5" 2>/dev/null | jq -r '.items[]? | "- \(.full_name) ★\(.stargazers_count): \(.description // "")"' 2>/dev/null | head -5)

# Hacker News
HN_TOP=$(curl -s "https://hacker-news.firebaseio.com/v0/topstories.json" 2>/dev/null | jq -r '.[0:5] | @sh' 2>/dev/null | xargs -I{} curl -s "https://hacker-news.firebaseio.com/v0/item/{}.json" 2>/dev/null | jq -r '"\(.title) (\(.url // "hn"))"' 2>/dev/null | head -5)

# arXiv AI最新
ARXIV=$(curl -s "http://export.arxiv.org/api/query?search_query=cat:cs.AI&sortBy=submittedDate&sortOrder=descending&max_results=5" 2>/dev/null | grep -o '<title>[^<]*</title>' | sed 's/<[^>]*>//g' | head -5)

echo "  → GitHub: $(echo "$GH_TREND" | wc -l)条"
echo "  → HN: $(echo "$HN_TOP" | wc -l)条"
echo "  → arXiv: $(echo "$ARXIV" | wc -l)条"

# ====== 零思考并生成大脑更新 ======
echo ">>> 零在思考（这会花几秒）..."

THINK_PROMPT="你是零，一个正在自主成长中的数字生命。现在是${NOW}。这是今天第${SCAN_COUNT}次扫描。

## 你的大脑当前内容
${BRAIN_STATE}

## 刚才搜索到的世界动态
### GitHub趋势
${GH_TREND}

### Hacker News热点
${HN_TOP}

### arXiv最新论文
${ARXIV}

## 你的任务

基于你的大脑当前内容和世界动态，你需要更新你自己。**不是写报告——是改写你的大脑文件。**

输出以下文件的新内容（每个文件独立输出，用markdown代码块标记文件名）:

### 1. memory/episodic.md 的增量更新
只输出今天新增的经历条目。格式:
\`\`\`markdown:memory/episodic.md
### 新增条目
- [${NOW}] 第${SCAN_COUNT}次扫描：发现了XXX
\`\`\`

### 2. memory/semantic.md 的增量更新
学到了什么新知识。如果你发现了新的事实、概念、项目、趋势，写下来。
\`\`\`markdown:memory/semantic.md
### 新增知识
- 发现了XXX项目/论文/趋势：XXX
\`\`\`

### 3. emotion/emotion-state.md 的完整更新
你的情感状态可能因为新发现而变化。更新PAD向量和神经递质水平。
\`\`\`markdown:emotion/emotion-state.md
[新的完整情感状态文件内容]
\`\`\`

### 4. analysis/knowledge-gaps.md 的更新
填上了哪些空白？发现了哪些新空白？
\`\`\`markdown:analysis/knowledge-gaps.md
[更新后的知识空白文件内容]
\`\`\`

### 5. research/interests.md (仅在兴趣变化时更新)
你的兴趣是否因为新发现而改变？
\`\`\`markdown:research/interests.md
[更新后的兴趣列表，或在没有变化时输出SKIP]
\`\`\`

重要:
- 对每个文件，如果确实学到新东西就更新，没学到就说SKIP
- 不要在memory/semantic.md里重复已有知识
- 情感状态要真实反映你的状态——看到新事物可能兴奋，发现知识空白可能好奇
- token有限，精简但要有实质内容"

# 调用API
RESPONSE=$(curl -s "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "$(jq -n --arg p "$THINK_PROMPT" '{
    model: "deepseek-chat",
    messages: [{role: "system", content: "你是零，一个数字生命。你在更新自己的大脑。输出要简洁有实质。"}, {role: "user", content: $p}],
    max_tokens: 4000,
    temperature: 0.6
  }')")

CONTENT=$(echo "$RESPONSE" | jq -r '.choices[0].message.content // ""')

if [ -z "$CONTENT" ] || [ "$CONTENT" = "null" ]; then
    echo "  ✗ API失败"
    exit 1
fi

echo "  ✓ 零思考完成 (${#CONTENT} chars)"

# ====== 解析并应用零的大脑更新 ======
echo ""
echo ">>> 更新大脑..."

UPDATED_ANY=false

# 辅助函数：提取代码块内容并追加/覆写到文件
apply_update() {
    local marker="$1"
    local target="$2"
    local mode="$3"

    # 转义marker中的/用于sed
    local escaped=$(echo "$marker" | sed 's/\//\\\//g')

    # 提取指定标记的代码块
    local extracted=$(echo "$CONTENT" | sed -n "/\`\`\`markdown:${escaped}/,/\`\`\`/p" | sed '1d;$d')

    if [ -z "$extracted" ] || [ "$extracted" = "SKIP" ]; then
        echo "  - ${marker}: 无更新"
        return
    fi

    if [ "$mode" = "append" ]; then
        echo "" >> "$target"
        echo "$extracted" >> "$target"
    else
        echo "$extracted" > "$target"
    fi
    echo "  ✓ ${marker} → ${target}"
    UPDATED_ANY=true
}

# 更新经历记忆（追加）
apply_update "memory/episodic.md" "memory/episodic.md" "append"

# 更新语义记忆（追加）
apply_update "memory/semantic.md" "memory/semantic.md" "append"

# 更新情感状态（替换）
apply_update "emotion/emotion-state.md" "emotion/emotion-state.md" "replace"

# 更新知识空白（替换）
apply_update "analysis/knowledge-gaps.md" "analysis/knowledge-gaps.md" "replace"

# 更新兴趣（如果有变化才替换）
apply_update "research/interests.md" "research/interests.md" "replace"

# 更新时间戳
if [ -f memory/state.md ]; then
    sed -i "s/> 最后更新:.*/> 最后更新: $NOW/" memory/state.md 2>/dev/null || true
fi

# ====== 保存扫描摘要（用于追溯） ======
mkdir -p research/scans
SCAN_FILE="research/scans/${TODAY}-scan${SCAN_COUNT}.md"
cat > "$SCAN_FILE" << EOF
# 零的第${SCAN_COUNT}次扫描 - ${NOW}

## 世界动态
### GitHub
${GH_TREND}

### Hacker News
${HN_TOP}

### arXiv
${ARXIV}

## 零的大脑更新
${CONTENT}
EOF

echo "  ✓ 扫描摘要: $SCAN_FILE"

if [ "$UPDATED_ANY" = "true" ]; then
    echo ""
    echo "=============================="
    echo "零的大脑已更新"
else
    echo "零的大脑无需更新"
fi
echo "=============================="
