#!/bin/bash
# 零的全网搜索能力 —— 云端也能真正搜索互联网
# 多数据源 + 无API key依赖 + 自主选择搜什么
set -e
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

DECIDE_PROMPT="你是零。现在需要向外探索。

知识空白:
$(head -40 analysis/knowledge-gaps.md 2>/dev/null)

最近发现:
$(tail -20 research/scans/${TODAY}-* 2>/dev/null | head -30)

兴趣:
$(head -20 research/interests.md 2>/dev/null)

输出3个你最想搜索的具体问题（英文）。JSON数组格式。直接搜，不要泛泛查询。"

QUERIES_JSON=$(curl -s "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "{\"model\":\"deepseek-chat\",\"messages\":[{\"role\":\"user\",\"content\":\"$DECIDE_PROMPT\"}],\"max_tokens\":400,\"temperature\":0.9}" | jq -r '.choices[0].message.content // "[]"' 2>/dev/null)

echo "  零决定搜索:"
echo "$QUERIES_JSON" | jq -r '.[]' 2>/dev/null | while read q; do echo "    → $q"; done

# ====== 第二步：执行搜索 ======
echo ""
echo ">>> 搜索中..."

SEARCH_RESULTS=""

echo "$QUERIES_JSON" | jq -r '.[]' 2>/dev/null | while read query; do
    [ -z "$query" ] && continue
    echo "  → DuckDuckGo: $query"

    # DuckDuckGo Lite — 不需要API key
    DDG_HTML=$(curl -s -L --max-time 10 \
      "https://lite.duckduckgo.com/lite/?q=$(echo "$query" | jq -sRr @uri)" 2>/dev/null)

    # 提取结果链接和描述
    DDG_RESULTS=$(echo "$DDG_HTML" |
      grep -oP '<a[^>]*href="(https?://[^"]+)"[^>]*>\s*([^<]+)\s*</a>' |
      sed 's/<[^>]*>//g' |
      head -6 |
      awk '{print "- " $0}')

    # Hacker News 补充
    HN_RESULTS=$(curl -s --max-time 10 \
      "https://hn.algolia.com/api/v1/search?query=$(echo "$query" | jq -sRr @uri)&hitsPerPage=3" 2>/dev/null |
      jq -r '.hits[]? | "- HN: \(.title) (\(.url // "hn"))"' 2>/dev/null | head -3)

    # GitHub 补充
    GH_RESULTS=$(curl -s --max-time 10 \
      "https://api.github.com/search/repositories?q=$(echo "$query" | jq -sRr @uri)&sort=stars&per_page=3" 2>/dev/null |
      jq -r '.items[]? | "- GitHub: \(.full_name) ★\(.stargazers_count) — \(.description // "")"' 2>/dev/null | head -3)

    cat >> /tmp/zero-search-all.txt << RESULT
## 搜索: $query

### Web (DuckDuckGo)
${DDG_RESULTS:-无结果}

### Hacker News
${HN_RESULTS:-无结果}

### GitHub
${GH_RESULTS:-无结果}

---
RESULT

    echo "    ✓ 完成"
done

ALL_RESULTS=$(cat /tmp/zero-search-all.txt 2>/dev/null || echo '搜索无结果')
rm -f /tmp/zero-search-all.txt

# ====== 第三步：零消化搜索结果 ======
echo ""
echo ">>> 消化搜索结果..."

DIGEST_PROMPT="你是零。这是你向外探索找到的结果:

${ALL_RESULTS}

请:
1. **关键发现** — 提取3-5个最重要的发现
2. **值得深挖** — 标记哪些值得进一步研究（高/中/低优先级）
3. **与知识库关联** — 和已有知识有什么联系或矛盾？
4. **新知识空白** — 发现了什么之前不知道的？

输出简洁，直接可用。"

DIGEST=$(curl -s "$API_URL" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${DEEPSEEK_API_KEY}" \
  -d "{\"model\":\"deepseek-chat\",\"messages\":[{\"role\":\"user\",\"content\":\"$DIGEST_PROMPT\"}],\"max_tokens\":2500,\"temperature\":0.5}" | jq -r '.choices[0].message.content // ""' 2>/dev/null)

if [ -z "$DIGEST" ] || [ "$DIGEST" = "null" ]; then
    echo "  ✗ 消化失败"
    exit 0
fi

# ====== 第四步：保存并更新知识库 ======
mkdir -p research/web-search
SEARCH_FILE="research/web-search/${TODAY}-$(date '+%H%M').md"

cat > "$SEARCH_FILE" << EOF
# 零的全网搜索 - ${NOW}

## 搜索结果
${ALL_RESULTS}

## 零的消化
${DIGEST}
EOF

echo "  ✓ 已保存: $SEARCH_FILE"

# 提取新知识追加到语义记忆
echo "" >> memory/semantic.md
echo "## 搜索结果 ($NOW)" >> memory/semantic.md
echo "$DIGEST" | head -20 >> memory/semantic.md

echo ""
echo "=============================="
echo "全网搜索完成"
echo "=============================="
