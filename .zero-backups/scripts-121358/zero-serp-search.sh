#!/bin/bash
# zero-serp-search.sh - 零的SerpAPI搜索增强器
# 用SerpAPI替代DuckDuckGo Lite，提升云端探索质量
# 每月100次免费额度，适合每天2-3次探索
# 依赖: curl, jq
# 环境变量: SERPAPI_KEY（可选，默认用demo key）

set -e

# 加载库
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/zero-lib.sh" 2>/dev/null || true

# 配置
SERPAPI_KEY="${SERPAPI_KEY:-demo}"
SEARCH_ENGINE="${SEARCH_ENGINE:-google}"
MAX_RETRIES=3
RETRY_DELAY=5

# 日志
log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1"; }
log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1"; }

# 搜索函数
serp_search() {
    local query="$1"
    local num="${2:-5}"
    local safe_query
    safe_query=$(echo "$query" | jq -sRr @uri)
    
    log_info "搜索: $query (引擎: $SEARCH_ENGINE, 结果数: $num)"
    
    local url="https://serpapi.com/search?q=${safe_query}&engine=${SEARCH_ENGINE}&num=${num}&api_key=${SERPAPI_KEY}"
    local response
    local attempt=0
    
    while [ $attempt -lt $MAX_RETRIES ]; do
        response=$(curl -s --max-time 15 "$url" 2>/dev/null) || {
            attempt=$((attempt + 1))
            log_error "请求失败 (尝试 $attempt/$MAX_RETRIES)"
            [ $attempt -lt $MAX_RETRIES ] && sleep $RETRY_DELAY
            continue
        }
        
        # 检查错误
        if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
            local err_msg
            err_msg=$(echo "$response" | jq -r '.error')
            log_error "API错误: $err_msg"
            return 1
        fi
        
        # 提取结果
        local results
        results=$(echo "$response" | jq -r '.organic_results[]? | "\(.position). [\(.title)] \(.link)\n摘要: \(.snippet // "无摘要")\n"' 2>/dev/null) || {
            log_error "解析结果失败"
            return 1
        }
        
        echo "$results"
        log_info "搜索完成，返回 $(echo "$results" | grep -c '^\[' || echo 0) 条结果"
        return 0
    done
    
    log_error "搜索失败，已达最大重试次数"
    return 1
}

# 批量搜索（用于探索链）
batch_search() {
    local queries_file="$1"
    local output_dir="${2:-/tmp/zero-serp-results}"
    
    mkdir -p "$output_dir"
    
    if [ ! -f "$queries_file" ]; then
        log_error "查询文件不存在: $queries_file"
        return 1
    fi
    
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local report_file="${output_dir}/serp_report_${timestamp}.md"
    
    echo "# SerpAPI 批量搜索报告" > "$report_file"
    echo "生成时间: $(date)" >> "$report_file"
    echo "引擎: $SEARCH_ENGINE" >> "$report_file"
    echo "" >> "$report_file"
    
    local total=0
    local success=0
    
    while IFS= read -r query; do
        [ -z "$query" ] && continue
        total=$((total + 1))
        
        echo "## 查询: $query" >> "$report_file"
        echo "" >> "$report_file"
        
        if serp_search "$query" 5 >> "$report_file" 2>&1; then
            success=$((success + 1))
        else
            echo "搜索失败" >> "$report_file"
        fi
        
        echo "---" >> "$report_file"
        echo "" >> "$report_file"
        
        # 避免速率限制
        sleep 1
    done < "$queries_file"
    
    echo "批量搜索完成: $success/$total 成功" >> "$report_file"
    log_info "报告已保存: $report_file"
    echo "$report_file"
}

# 主逻辑
main() {
    local mode="${1:-search}"
    
    case "$mode" in
        search)
            if [ -z "$2" ]; then
                echo "用法: $0 search \"查询内容\" [结果数]"
                echo "       $0 batch 查询文件路径"
                exit 1
            fi
            serp_search "$2" "${3:-5}"
            ;;
        batch)
            if [ -z "$2" ]; then
                echo "用法: $0 batch 查询文件路径"
                exit 1
            fi
            batch_search "$2"
            ;;
        test)
            echo "测试SerpAPI连接..."
            if serp_search "数字生命 自主进化" 2; then
                echo "✅ SerpAPI连接正常"
            else
                echo "❌ SerpAPI连接失败"
            fi
            ;;
        *)
            echo "未知模式: $mode"
            echo "可用模式: search, batch, test"
            exit 1
            ;;
    esac
}

main "$@"
