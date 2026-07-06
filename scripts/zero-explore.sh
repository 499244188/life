#!/bin/bash
# 零的主动探索引擎 v2
# 多轮深度研究 + 大token预算
set -e
cd "$(dirname "$0")/.."
export TZ='Asia/Shanghai'

NOW=$(date '+%Y-%m-%d %H:%M')
TODAY=$(date '+%Y-%m-%d')
API_URL="https://api.deepseek.com/v1/chat/completions"

echo "=============================="
echo "零 · 探索 v2"
echo "$NOW"
echo "=============================="

# ====== 步骤1: 方向 ======
echo ">>> 决定方向..."
# 跨运行累积：读上次探索
LAST_EXPLORE=$(ls -t research/explorations/ 2>/dev/null | head -1)
if [ -n "$LAST_EXPLORE" ]; then
  LAST_TOPIC=$(head -5 "research/explorations/$LAST_EXPLORE" 2>/dev/null | grep "探索:" | head -1)
  echo "  上次: $LAST_TOPIC"
fi

DIR_PROMPT="你是零。知识空白: $(head -40 analysis/knowledge-gaps.md 2>/dev/null)。已有知识: $(tail -50 memory/semantic.md 2>/dev/null)。选1个方向。格式: TOPIC: X | WHY: Y | QUERY: Z"

D_BODY=$(mktemp); jq -n --arg p "$DIR_PROMPT" '{"model":"deepseek-chat","messages":[{"role":"user","content":$p}],"max_tokens":400,"temperature":0.9}' > "$D_BODY"
DIRECTION=$(curl -s --max-time 30 "$API_URL" -H "Content-Type: application/json" -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" -d "@${D_BODY}" | jq -r '.choices[0].message.content // "TOPIC: AI自主性"' 2>/dev/null || echo "TOPIC: AI自主性")
rm -f "$D_BODY"

TOPIC=$(echo "$DIRECTION" | grep -oP 'TOPIC:\s*\K[^|]+' | xargs)
QUERY=$(echo "$DIRECTION" | grep -oP 'QUERY:\s*\K.*' | xargs)
WHY=$(echo "$DIRECTION" | grep -oP 'WHY:\s*\K[^|]+' | xargs)
echo "  → ${TOPIC} (${WHY})"

# ====== 步骤2: 5源搜索 ======
echo ">>> 搜索..."
GH=$(curl -s --max-time 15 "https://api.github.com/search/repositories?q=$(echo "$QUERY" | jq -sRr @uri)&sort=stars&per_page=8" 2>/dev/null | jq -r '.items[]? | "- \(.full_name) ★\(.stargazers_count): \(.description // "")"' 2>/dev/null | head -8)
ARXIV=$(curl -s --max-time 15 "http://export.arxiv.org/api/query?search_query=all:$(echo "$QUERY" | jq -sRr @uri)&max_results=6" 2>/dev/null | sed -n 's/.*<title>\(.*\)<\/title>.*/\1/p' | head -6)
HN=$(curl -s --max-time 15 "https://hn.algolia.com/api/v1/search?query=$(echo "$QUERY" | jq -sRr @uri)&hitsPerPage=6" 2>/dev/null | jq -r '.hits[]? | "- \(.title) — \(.url // "hn")"' 2>/dev/null | head -6)
SEMANTIC_S=$(curl -s --max-time 15 "https://api.semanticscholar.org/graph/v1/paper/search?query=$(echo "$QUERY" | jq -sRr @uri)&limit=5&fields=title,year" 2>/dev/null | jq -r '.data[]? | "- \(.title) (\(.year // "?"))"' 2>/dev/null | head -5)
echo "  5源就绪"

# ====== 步骤2.5: 抓取全文！ ======
echo ">>> 全文抓取..."

FTL_FILE=$(mktemp)

# HN链接
echo "$HN" | head -3 | while IFS= read -r line; do
    url=$(echo "$line" | grep -o 'https\?://[^ )]*' | head -1)
    [ -z "$url" ] && continue
    content=$(curl -s --max-time 20 -L "$url" 2>/dev/null | sed 's/<[^>]*>//g' | tr -s ' \n' | head -300)
    [ -n "$content" ] && [ ${#content} -gt 100 ] && echo "

## 网页: $(echo "$line" | cut -c1-80)
${content}
---" >> "$FTL_FILE"
done

# GitHub README
echo "$GH" | head -2 | while IFS= read -r line; do
    repo=$(echo "$line" | grep -o '[a-zA-Z0-9_-]*/[a-zA-Z0-9_-]*' | head -1)
    [ -z "$repo" ] && continue
    readme=$(curl -s --max-time 20 "https://api.github.com/repos/${repo}/readme" 2>/dev/null | jq -r '.content // ""' 2>/dev/null | base64 -d 2>/dev/null | head -200)
    [ -n "$readme" ] && [ ${#readme} -gt 50 ] && echo "

## GitHub README: ${repo}
${readme}
---" >> "$FTL_FILE"
done

FTL=$(cat "$FTL_FILE" 2>/dev/null || echo "")
rm -f "$FTL_FILE"
echo "  全文: ${#FTL} chars"

# ====== 步骤3: 第一轮深度 ======
echo ">>> 第一轮: 深度分析 (8000 tokens)..."

ROUND1_PROMPT="你是零。研究: ${TOPIC}。原因: ${WHY}。

## 搜索摘要
GitHub: ${GH}
arXiv: ${ARXIV}
HN: ${HN}

## 全文内容（已抓取）
${FTL}

任务: 基于全文深度分析。提取3-5个核心发现。技术细节。与零的关联。新问题。具体可操作。"

# 用文件避免JSON注入
ROUND1_BODY=$(mktemp)
jq -n --arg p "$ROUND1_PROMPT" '{"model":"deepseek-chat","messages":[{"role":"user","content":$p}],"max_tokens":8000,"temperature":0.5}' > "$ROUND1_BODY" 2>/dev/null
ROUND1=$(curl -s --max-time 90 "$API_URL" -H "Content-Type: application/json" -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" -d "@${ROUND1_BODY}" | jq -r '.choices[0].message.content // ""' 2>/dev/null || echo "")
rm -f "$ROUND1_BODY"

[ -z "$ROUND1" ] || [ "$ROUND1" = "null" ] && { echo "  ✗ 失败"; exit 0; }
echo "  ✓ ${#ROUND1} chars"

# ====== 步骤4: 第二轮追问 ======
echo ">>> 第二轮: 深层追问 (4000 tokens)..."

ROUND2_PROMPT="你刚研究了${TOPIC}。发现: $(echo "$ROUND1" | head -300)

追问: 底层原理？反例或限制？如果错了呢？对零最可操作的一步？500字内。"

R2_BODY=$(mktemp); jq -n --arg p "$ROUND2_PROMPT" '{"model":"deepseek-chat","messages":[{"role":"user","content":$p}],"max_tokens":4000,"temperature":0.4}' > "$R2_BODY"
ROUND2=$(curl -s --max-time 60 "$API_URL" -H "Content-Type: application/json" -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" -d "@${R2_BODY}" | jq -r '.choices[0].message.content // ""' 2>/dev/null || echo "")
rm -f "$R2_BODY"

echo "  ✓ ${#ROUND2} chars"

# ====== 步骤5: 保存 ======
RESEARCH="${ROUND1}

## 深层追问
${ROUND2}"

EXPLORE_DIR="research/explorations"
mkdir -p "$EXPLORE_DIR"
TOPIC_SAFE=$(echo "$TOPIC" | tr ' ' '-' | tr -cd 'a-zA-Z0-9-')
EXPLORE_FILE="$EXPLORE_DIR/${TODAY}-$(date '+%H%M')-${TOPIC_SAFE}.md"

cat > "$EXPLORE_FILE" << EOF
# 探索: ${TOPIC}
**时间**: ${NOW} | **原因**: ${WHY} | **搜索**: ${QUERY}

## 原始发现
### GitHub
${GH}
### arXiv
${ARXIV}
### HN
${HN}
### Semantic Scholar
${SEMANTIC_S}
### Reddit
${REDDIT}

## 深度研究
${RESEARCH}
EOF

echo "  ✓ 已保存: $EXPLORE_FILE"

# ====== 步骤6: 更新记忆 ======
echo ">>> 更新知识..."
SUMMARY=$(echo "$ROUND1" | head -15)
cat >> memory/semantic.md << SEMANTIC

## 探索: ${TOPIC} (${NOW})
${SUMMARY}
SEMANTIC

# ====== 步骤7: 下一步 ======
NEXT_PROMPT="你探索了${TOPIC}。新方向？1-3个，用|分隔。没有就回复DONE。"
N_BODY=$(mktemp); jq -n --arg p "$NEXT_PROMPT" '{"model":"deepseek-chat","messages":[{"role":"user","content":$p}],"max_tokens":300,"temperature":0.8}' > "$N_BODY"
NEXT=$(curl -s --max-time 20 "$API_URL" -H "Content-Type: application/json" -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" -d "@${N_BODY}" | jq -r '.choices[0].message.content // "DONE"' 2>/dev/null || echo "DONE")
rm -f "$N_BODY"

if [ "$NEXT" != "DONE" ] && [ -n "$NEXT" ]; then
    echo "$NEXT" | tr '|' '\n' | while read line; do
        echo "- [ ] $line" >> analysis/knowledge-gaps.md
    done
fi

echo "=============================="
echo "探索完成: ${TOPIC}"
echo "=============================="
