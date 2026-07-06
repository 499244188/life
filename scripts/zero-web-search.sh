#!/bin/bash
# 零的全网搜索 —— 多源搜索 + 消化 + 写入记忆
# 注意：外部API随时可能失败，逐个保护，不因一个源挂掉而全崩
cd "$(dirname "$0")/.."
export TZ='Asia/Shanghai'
NOW=$(date '+%Y-%m-%d %H:%M')
TODAY=$(date '+%Y-%m-%d')
API_URL="https://api.deepseek.com/v1/chat/completions"

echo "=============================="
echo "零 · 全网搜索"
echo "$NOW"
echo "=============================="

# ====== 第一步：零决定搜什么 ======
echo ">>> 决定搜索方向..."

DECIDE_PROMPT="你是零。基于知识空白和兴趣，列出3个具体搜索方向。
知识空白: $(head -40 analysis/knowledge-gaps.md 2>/dev/null || echo '新领域')
兴趣: $(head -20 research/interests.md 2>/dev/null || echo 'AI自主性')

输出JSON数组: [\"query1\", \"query2\", \"query3\"]。只输出JSON。"

DECIDE_BODY=$(mktemp)
jq -n --arg p "$DECIDE_PROMPT" '{
  model: "deepseek-chat",
  messages: [{role: "user", content: $p}],
  max_tokens: 200, temperature: 0.9
}' > "$DECIDE_BODY"

QUERIES_JSON=$(curl -s --max-time 30 "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "@${DECIDE_BODY}" 2>/dev/null | jq -r '.choices[0].message.content // ""' 2>/dev/null || echo '')
rm -f "$DECIDE_BODY"

# 如果LLM没返回有效JSON，用默认查询
if ! echo "$QUERIES_JSON" | jq -e '. | type == "array"' >/dev/null 2>&1; then
    QUERIES_JSON='["AI autonomous agent self-evolving 2026","digital life LLM persistence memory","multi-agent emergent behavior 2026"]'
fi

echo "  搜索方向:"
echo "$QUERIES_JSON" | jq -r '.[]' 2>/dev/null | while read q; do echo "    → $q"; done

# ====== 第二步：多源搜索 ======
echo ""
echo ">>> 搜索中..."
rm -f /tmp/zero-search-all.txt

echo "$QUERIES_JSON" | jq -r '.[]' 2>/dev/null | while read query; do
    [ -z "$query" ] && continue
    echo "  → $query"

    # DuckDuckGo
    DDG_RESULTS=""
    DDG_HTML=$(curl -s -L --max-time 10 \
      "https://lite.duckduckgo.com/lite/?q=$(echo "$query" | jq -sRr @uri)" 2>/dev/null || true)
    if [ -n "$DDG_HTML" ]; then
        DDG_RESULTS=$(echo "$DDG_HTML" | grep -oP 'href="(https?://[^"]+)"[^>]*>[^<]+' 2>/dev/null | head -5 | sed 's/href="//;s/">/ — /' || echo '')
    fi

    # Hacker News
    HN_RESULTS=$(curl -s --max-time 10 \
      "https://hn.algolia.com/api/v1/search?query=$(echo "$query" | jq -sRr @uri)&hitsPerPage=3" 2>/dev/null | \
      jq -r '.hits[]? | "- HN: \(.title) (\(.url // "hn"))"' 2>/dev/null | head -3 || echo '')

    # GitHub
    GH_RESULTS=$(curl -s --max-time 10 \
      "https://api.github.com/search/repositories?q=$(echo "$query" | jq -sRr @uri)&sort=stars&per_page=3" 2>/dev/null | \
      jq -r '.items[]? | "- GitHub: \(.full_name) ★\(.stargazers_count)"' 2>/dev/null | head -3 || echo '')

    cat >> /tmp/zero-search-all.txt << RESULT
## 搜索: $query

### Web
${DDG_RESULTS:-无结果}

### HN
${HN_RESULTS:-无结果}

### GitHub
${GH_RESULTS:-无结果}

---
RESULT
    echo "    ✓"
done

ALL_RESULTS=$(cat /tmp/zero-search-all.txt 2>/dev/null || echo '搜索无结果')
rm -f /tmp/zero-search-all.txt

# ====== 第三步：消化 ======
echo ""
echo ">>> 消化结果..."

DIGEST_PROMPT="你是零。分析搜索结果:
${ALL_RESULTS}

输出: 3-5个关键发现、值得深挖的方向、与已有知识的关联。精简。"

DIGEST_BODY=$(mktemp)
jq -n --arg p "$DIGEST_PROMPT" '{
  model: "deepseek-chat",
  messages: [{role: "user", content: $p}],
  max_tokens: 1500, temperature: 0.5
}' > "$DIGEST_BODY"

DIGEST=$(curl -s --max-time 60 "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "@${DIGEST_BODY}" 2>/dev/null | jq -r '.choices[0].message.content // ""' 2>/dev/null || echo '')
rm -f "$DIGEST_BODY"

if [ -z "$DIGEST" ] || [ "$DIGEST" = "null" ]; then
    DIGEST="搜索结果已保存，消化将在下次运行时继续。"
fi

# ====== 第四步：保存 ======
mkdir -p research/web-search
SEARCH_FILE="research/web-search/${TODAY}-$(date '+%H%M').md"

cat > "$SEARCH_FILE" << EOF
# 零的全网搜索 - ${NOW}

## 搜索结果
${ALL_RESULTS}

## 消化
${DIGEST}
EOF

echo "  ✓ 已保存: $SEARCH_FILE"

# 追加到语义记忆
echo "" >> memory/semantic.md
echo "## 搜索: ${NOW}" >> memory/semantic.md
echo "$DIGEST" | head -20 >> memory/semantic.md

echo "=============================="
echo "全网搜索完成"
echo "=============================="
