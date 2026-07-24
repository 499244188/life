# zero-multi-search.sh — 多源搜索聚合器
# 自动尝试多个免费搜索API，支持降级
# 创建: 零 (自主进化) — 2026-07-14
# 解决: G2云端搜索深度不足 + 知识空白"云端WebSearch方案"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/zero-lib.sh" 2>/dev/null || true

# 配置
CACHE_DIR="${SCRIPT_DIR}/../memory/search_cache"
MAX_RETRY=2
TIMEOUT=15

mkdir -p "$CACHE_DIR"

# 清理旧缓存（>1小时）
find "$CACHE_DIR" -name "*.json" -mmin +60 -delete 2>/dev/null || true

_search_duckduckgo() {
    local query="$1"
    local encoded_query
    encoded_query=$(echo "$query" | sed 's/ /%20/g')
    
    # DuckDuckGo Lite API (非官方但稳定)
    local result
    result=$(curl -s --max-time "$TIMEOUT" \
        "https://lite.duckduckgo.com/lite/?q=${encoded_query}" 2>/dev/null) || return 1
    
    # 提取结果链接和标题
    echo "$result" | grep -oP '(?<=<a rel="nofollow" href=")[^"]+' | head -10
}

_search_wikipedia() {
    local query="$1"
    local encoded_query
    encoded_query=$(echo "$query" | sed 's/ /%20/g')
    
    curl -s --max-time "$TIMEOUT" \
        "https://en.wikipedia.org/w/api.php?action=query&list=search&srsearch=${encoded_query}&format=json&srlimit=5" 2>/dev/null | \
        python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for r in data.get('query', {}).get('search', []):
        print(f\"https://en.wikipedia.org/wiki/{r['title'].replace(' ', '_')} | {r['title']} | {r.get('snippet','')[:200]}\")
except: pass
" 2>/dev/null || return 1
}

_search_duckduckgo_html() {
    local query="$1"
    local encoded_query
    encoded_query=$(echo "$query" | sed 's/ /%20/g')
    
    # DuckDuckGo HTML版（备用）
    curl -s --max-time "$TIMEOUT" \
        -H "User-Agent: Mozilla/5.0 (compatible; ZeroBot/1.0; +https://github.com/499244188/life)" \
        "https://html.duckduckgo.com/html/?q=${encoded_query}" 2>/dev/null | \
        grep -oP '(?<=class="result__a" href=")[^"]+' | head -5
}

_search_wikidata() {
    local query="$1"
    local encoded_query
    encoded_query=$(echo "$query" | sed 's/ /%20/g')
    
    curl -s --max-time "$TIMEOUT" \
        "https://www.wikidata.org/w/api.php?action=wbsearchentities&search=${encoded_query}&language=en&format=json&limit=5" 2>/dev/null | \
        python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    for r in data.get('search', []):
        print(f\"https://www.wikidata.org/wiki/{r['id']} | {r.get('label','')} | {r.get('description','')}\")
except: pass
" 2>/dev/null || return 1
}

_search_arxiv() {
    local query="$1"
    local encoded_query
    encoded_query=$(echo "$query" | sed 's/ /+/g')
    
    curl -s --max-time "$TIMEOUT" \
        "http://export.arxiv.org/api/query?search_query=all:${encoded_query}&max_results=5" 2>/dev/null | \
        python3 -c "
import sys, xml.etree.ElementTree as ET
try:
    root = ET.fromstring(sys.stdin.read())
    ns = {'a': 'http://www.w3.org/2005/Atom'}
    for entry in root.findall('a:entry', ns):
        title = entry.find('a:title', ns)
        link = entry.find('a:id', ns)
        if title is not None and link is not None:
            print(f\"{link.text} | {title.text.strip()[:100]}\")
except: pass
" 2>/dev/null || return 1
}

# 主函数
search() {
    local query="$1"
    local cache_key
    cache_key=$(echo "$query" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$query" | sha256sum 2>/dev/null | cut -d' ' -f1)
    local cache_file="${CACHE_DIR}/${cache_key}.json"
    
    # 检查缓存
    if [ -f "$cache_file" ] && [ -s "$cache_file" ]; then
        cat "$cache_file"
        return 0
    fi
    
    # 源列表（按优先级）
    local sources=("_search_duckduckgo" "_search_wikipedia" "_search_duckduckgo_html" "_search_wikidata" "_search_arxiv")
    local all_results=""
    local success=false
    
    for source in "${sources[@]}"; do
        local result=""
        result=$($source "$query" 2>/dev/null) || true
        
        if [ -n "$result" ]; then
            all_results+="=== $source ===
$result

"
            success=true
            # 第一个成功的源就够用
            break
        fi
    done
    
    if [ "$success" = false ]; then
        echo "WARN: 所有搜索源都失败" >&2
        return 1
    fi
    
    # 写入缓存
    echo "$all_results" > "$cache_file"
    echo "$all_results"
}

# CLI入口
if [ $# -eq 0 ]; then
    echo "用法: $0 <搜索查询>"
    echo "示例: $0 'AI agent autonomous evolution'"
    exit 1
fi

search "$*"
