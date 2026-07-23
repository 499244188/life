# ============================================================
# 零 - 认知更新引擎 v1
# 功能: 从运行日志中提取新知识，更新记忆文件
# 模式来源: zero-cognition-update.sh 的7次成功调用
# 特点: 可独立运行，支持自定义输入/输出，带证据锚点
# ============================================================
set -e

# --- 配置 ---
: "${LOG_DIR:=.}"                    # 日志目录
: "${MEMORY_FILE:=memory.md}"        # 记忆文件
: "${EVIDENCE_DIR:=.evidence}"       # 证据目录
: "${MIN_CONFIDENCE:=0.6}"           # 最低置信度
: "${MAX_NEW_FACTS:=5}"              # 单次最大新事实数

# --- 辅助函数 ---
log() { echo "[cog-update] $*"; }
error() { echo "[cog-update] ERROR: $*" >&2; }

# 提取最新运行日志
extract_logs() {
    local log_file="$LOG_DIR/latest-run.log"
    if [ -f "$log_file" ]; then
        cat "$log_file"
        return 0
    fi
    # 尝试从GitHub Actions日志提取
    if [ -n "$GITHUB_STEP_SUMMARY" ]; then
        cat "$GITHUB_STEP_SUMMARY" 2>/dev/null || return 1
    fi
    return 1
}

# 从日志提取新事实（简单模式：匹配"发现"、"学到"、"新"等关键词）
extract_facts() {
    local input="$1"
    echo "$input" | grep -oiE '(发现[：:].*|学到[：:].*|新[知事].*|learned[：:].*|found[：:].*)' | head -n "$MAX_NEW_FACTS" || true
}

# 检查事实是否已存在于记忆
is_new_fact() {
    local fact="$1"
    local mem_file="$2"
    if [ ! -f "$mem_file" ]; then
        return 0  # 记忆文件不存在，视为新事实
    fi
    if grep -qiF "$fact" "$mem_file" 2>/dev/null; then
        return 1  # 已存在
    fi
    return 0
}

# 保存证据（不可变）
save_evidence() {
    local fact="$1"
    local evidence_id
    evidence_id=$(echo "$fact" | sha256sum | cut -c1-16)
    local evidence_file="$EVIDENCE_DIR/${evidence_id}.ev"
    mkdir -p "$EVIDENCE_DIR"
    {
        echo "timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo "source: ${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"
        echo "fact: $fact"
        echo "confidence: $MIN_CONFIDENCE"
    } > "$evidence_file"
    echo "$evidence_id"
}

# 追加到记忆文件
append_memory() {
    local fact="$1"
    local evidence_id="$2"
    local mem_file="$3"
    {
        echo ""
        echo "- $(date -u +%Y-%m-%d) | 认知更新: $fact"
        echo "  证据: $evidence_id"
    } >> "$mem_file"
    log "记忆已更新: $fact"
}

# --- 主流程 ---
main() {
    log "认知更新引擎启动"
    
    # 1. 提取日志
    local logs
    logs=$(extract_logs) || {
        error "无法提取日志"
        return 1
    }
    
    # 2. 提取事实
    local facts
    facts=$(extract_facts "$logs") || {
        log "未发现新事实"
        return 0
    }
    
    if [ -z "$facts" ]; then
        log "日志中无新知识"
        return 0
    fi
    
    # 3. 逐条处理
    local count=0
    while IFS= read -r fact; do
        [ -z "$fact" ] && continue
        if is_new_fact "$fact" "$MEMORY_FILE"; then
            local eid
            eid=$(save_evidence "$fact")
            append_memory "$fact" "$eid" "$MEMORY_FILE"
            count=$((count + 1))
        fi
    done <<< "$facts"
    
    log "完成: 新增 $count 条认知"
    return 0
}
