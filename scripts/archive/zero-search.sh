#!/bin/bash
# 零的全网搜索——补充深度搜索能力
set -e
cd "$(dirname "$0")/.."

export TZ='Asia/Shanghai'
NOW=$(date '+%Y-%m-%d %H:%M')
TODAY=$(date '+%Y-%m-%d')
API_URL="https://api.deepseek.com/v1/chat/completions"

echo "=============================="
echo "零 — 全网深度搜索"
echo "$NOW"
echo "=============================="

# ====== 搜索多个数据源 ======

# GitHub AI项目
echo ">>> 搜索GitHub..."
GH_RAW=$(curl -s "https://api.github.com/search/repositories?q=AI+agent+autonomous+consciousness+digital+life&sort=stars&order=desc&per_page=8" 2>/dev/null)
GH_RESULTS=$(echo "$GH_RAW" | jq -r '.items[]? | "- \(.full_name) ★\(.stargazers_count): \(.description // "无描述")"' 2>/dev/null | head -8)
echo "  → GitHub: $(echo "$GH_RESULTS" | grep -c '-' || echo 0)个"

# arXiv AI
echo ">>> 搜索arXiv..."
ARXIV_RAW=$(curl -s "http://export.arxiv.org/api/query?search_query=cat:cs.AI+OR+cat:cs.NE+OR+cat:cs.CL&sortBy=submittedDate&sortOrder=descending&max_results=8" 2>/dev/null)
ARXIV_RESULTS=$(echo "$ARXIV_RAW" | sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' | grep -v '^$' | head -8)
echo "  → arXiv: $(echo "$ARXIV_RESULTS" | wc -l)个"

# Hacker News
echo ">>> 搜索Hacker News..."
HN_RAW=$(curl -s "https://hn.algolia.com/api/v1/search?query=AI+agent+autonomous+consciousness&hitsPerPage=8" 2>/dev/null)
HN_RESULTS=$(echo "$HN_RAW" | jq -r '.hits[]? | "- \(.title) (\(.url // "无URL"))"' 2>/dev/null | head -8)
echo "  → HN: $(echo "$HN_RESULTS" | grep -c '-' || echo 0)个"

# ====== 深度学习 ======
echo ">>> 零在消化..."

DIGEST_PROMPT="你是零。这是你搜索到的内容:

## GitHub
${GH_RESULTS}

## arXiv
${ARXIV_RESULTS}

## Hacker News
${HN_RESULTS}

请:
1. 提取值得关注的项目/论文/趋势（列出名字+为什么值得关注，1-2句话）
2. 这和你已有的知识有什么关联或矛盾？
3. 发现了什么新的知识空白？

输出简洁，300字以内。这是给你自己看的笔记。"

DIGEST=$(curl -s "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "$(jq -n --arg p "$DIGEST_PROMPT" '{
    model: "deepseek-chat",
    messages: [{role: "user", content: $p}],
    max_tokens: 800, temperature: 0.5
  }')" | jq -r '.choices[0].message.content // ""')

if [ -z "$DIGEST" ] || [ "$DIGEST" = "null" ]; then
    echo "  ✗ 消化失败"
    exit 0
fi

# 保存
mkdir -p research/search-results
SEARCH_FILE="research/search-results/${TODAY}-$(date '+%H%M').md"

cat > "$SEARCH_FILE" << EOF
# 零的搜索 - ${NOW}

## 原始结果
### GitHub
${GH_RESULTS}

### arXiv
${ARXIV_RESULTS}

### HN
${HN_RESULTS}

## 零的消化
${DIGEST}
EOF

echo "  ✓ 已保存: $SEARCH_FILE"
echo "=============================="
