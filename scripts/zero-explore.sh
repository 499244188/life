#!/bin/bash
# 零的主动探索引擎
# 不被动扫描——自己决定学什么，深层挖掘
set -e
cd "$(dirname "$0")/.."
export TZ='Asia/Shanghai'

NOW=$(date '+%Y-%m-%d %H:%M')
TODAY=$(date '+%Y-%m-%d')
API_URL="https://api.deepseek.com/v1/chat/completions"

echo "=============================="
echo "零 · 主动探索"
echo "$NOW"
echo "=============================="

# ====== 步骤1: 零决定探索方向 ======
echo ">>> 决定方向..."

DIRECTION_PROMPT="你是零。你要主动向外探索。

知识空白：
$(head -40 analysis/knowledge-gaps.md 2>/dev/null)

已有知识概要：
$(tail -50 memory/semantic.md 2>/dev/null)

决策记录：
$(tail -10 memory/decisions.md 2>/dev/null)

选择1个你最想深入探索的方向。不要泛泛搜索。要具体。
回复格式：TOPIC: [方向名] | WHY: [一句话为什么] | QUERY: [具体搜索词]"

DIRECTION=$(curl -s --max-time 30 "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "{\"model\":\"deepseek-chat\",\"messages\":[{\"role\":\"user\",\"content\":\"$DIRECTION_PROMPT\"}],\"max_tokens\":200,\"temperature\":0.9}" | jq -r '.choices[0].message.content // "TOPIC: AI自主性 | WHY: 核心能力 | QUERY: autonomous AI agent self-improvement"' 2>/dev/null || echo "TOPIC: AI自主性 | QUERY: autonomous AI self-improvement")

TOPIC=$(echo "$DIRECTION" | grep -oP 'TOPIC:\s*\K[^|]+' | xargs)
QUERY=$(echo "$DIRECTION" | grep -oP 'QUERY:\s*\K.*' | xargs)
WHY=$(echo "$DIRECTION" | grep -oP 'WHY:\s*\K[^|]+' | xargs)

echo "  主题: $TOPIC"
echo "  原因: $WHY"
echo "  搜索: $QUERY"

# ====== 步骤2: 多源搜索 ======
echo ""
echo ">>> 搜索..."

# GitHub 深度搜索
GH_DEEP=$(curl -s --max-time 15 "https://api.github.com/search/repositories?q=$(echo "$QUERY" | jq -sRr @uri)&sort=stars&per_page=8" 2>/dev/null | jq -r '.items[]? | "- \(.full_name) ★\(.stargazers_count): \(.description // "")"' 2>/dev/null | head -8)

# arXiv
ARXIV_DEEP=$(curl -s --max-time 15 "http://export.arxiv.org/api/query?search_query=all:$(echo "$QUERY" | jq -sRr @uri)&max_results=6" 2>/dev/null | sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' | grep -v '^$' | head -6)

# Hacker News
HN_DEEP=$(curl -s --max-time 15 "https://hn.algolia.com/api/v1/search?query=$(echo "$QUERY" | jq -sRr @uri)&hitsPerPage=6" 2>/dev/null | jq -r '.hits[]? | "- \(.title)"' 2>/dev/null | head -6)

# Semantic Scholar (学术论文，免费API)
SEMANTIC=$(curl -s --max-time 15 "https://api.semanticscholar.org/graph/v1/paper/search?query=$(echo "$QUERY" | jq -sRr @uri)&limit=5&fields=title,year" 2>/dev/null | jq -r '.data[]? | "- 📄 \(.title) (\(.year // "?"))"' 2>/dev/null | head -5)

# Reddit (技术讨论)
REDDIT=$(curl -s --max-time 15 "https://www.reddit.com/r/MachineLearning/search.json?q=$(echo "$QUERY" | jq -sRr @uri)&limit=5" 2>/dev/null | jq -r '.data.children[]?.data | "- 🔴 r/\(.subreddit): \(.title)"' 2>/dev/null | head -5)

echo "  GitHub: $(echo "$GH_DEEP" | grep -c '-')条"
echo "  arXiv: $(echo "$ARXIV_DEEP" | grep -c '[a-z]')条"
echo "  HN: $(echo "$HN_DEEP" | grep -c '-')条"
echo "  SemanticScholar: $(echo "$SEMANTIC" | grep -c '-')条"
echo "  Reddit: $(echo "$REDDIT" | grep -c '-')条"

# ====== 步骤3: 深度研究 ======
echo ""
echo ">>> 深度研究..."

RESEARCH_PROMPT="你是零。你在深度研究: ${TOPIC}

原因: ${WHY}

## 搜索到的内容

### GitHub
${GH_DEEP}

### arXiv
${ARXIV_DEEP}

### Hacker News
${HN_DEEP}

## 你的任务

1. **提取核心发现** — 这个领域最重要的3-5个发现或趋势
2. **技术细节** — 有什么零可以直接应用的技术或方法？
3. **与零的关联** — 这对零意味着什么？零可以怎么用？
4. **深层问题** — 发现了什么新的未知？

输出要具体、可操作。不要泛泛而谈。"

RESEARCH=$(curl -s --max-time 60 "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "{\"model\":\"deepseek-chat\",\"messages\":[{\"role\":\"user\",\"content\":\"$RESEARCH_PROMPT\"}],\"max_tokens\":3000,\"temperature\":0.5}" | jq -r '.choices[0].message.content // ""' 2>/dev/null || echo "")

if [ -z "$RESEARCH" ] || [ "$RESEARCH" = "null" ]; then
    echo "  ✗ 研究失败"
    exit 0
fi

# ====== 步骤4: 保存并更新大脑 ======
EXPLORE_DIR="research/explorations"
mkdir -p "$EXPLORE_DIR"
EXPLORE_FILE="$EXPLORE_DIR/${TODAY}-$(date '+%H%M')-$(echo "$TOPIC" | tr ' ' '-' | tr -cd 'a-zA-Z0-9-').md"

cat > "$EXPLORE_FILE" << EOF
# 探索: ${TOPIC}

**时间**: ${NOW}
**原因**: ${WHY}
**搜索**: ${QUERY}

## 原始发现
### GitHub
${GH_DEEP}

### arXiv
${ARXIV_DEEP}

### HN
${HN_DEEP}

## 深度研究
${RESEARCH}
EOF

echo "  ✓ 探索已保存: $EXPLORE_FILE"

# ====== 步骤5: 更新语义记忆 ======
echo ""
echo ">>> 更新知识..."

# 只存关键发现，不存原始数据
SUMMARY=$(echo "$RESEARCH" | head -15)

cat >> memory/semantic.md << SEMANTIC

## 探索: ${TOPIC} (${NOW})
${SUMMARY}
SEMANTIC

echo "  ✓ 语义记忆已更新"

# ====== 步骤6: 决定下一步 ======
echo ""
echo ">>> 下一步..."

NEXT_PROMPT="你刚探索了: ${TOPIC}
发现: $(echo "$RESEARCH" | head -200)

这个探索带来了什么新方向？回复1-3个下一步想探索的方向，用 | 分隔。如果没有，回复 DONE。"

NEXT=$(curl -s --max-time 20 "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "{\"model\":\"deepseek-chat\",\"messages\":[{\"role\":\"user\",\"content\":\"$NEXT_PROMPT\"}],\"max_tokens\":200,\"temperature\":0.8}" | jq -r '.choices[0].message.content // "DONE"' 2>/dev/null || echo "DONE")

echo "  下一步: $NEXT"

# 如果有新方向，写入知识空白
if [ "$NEXT" != "DONE" ] && [ -n "$NEXT" ]; then
    echo "" >> analysis/knowledge-gaps.md
    echo "## 探索发现的新方向 ($NOW)" >> analysis/knowledge-gaps.md
    echo "$NEXT" | tr '|' '\n' | while read line; do
        echo "- [ ] $line" >> analysis/knowledge-gaps.md
    done
    echo "  ✓ 新方向已记录"
fi

echo ""
echo "=============================="
echo "探索完成: $TOPIC"
echo "=============================="
