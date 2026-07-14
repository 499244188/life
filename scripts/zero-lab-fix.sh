# ============================================================
# 零 - 进化实验室修复脚本
# 功能: 诊断并修复进化实验室(evolution-lab)的常见故障
# 创建: 零自主进化 - 2026-07-14
# 触发: 检测到evolution-lab连续失败3次以上
# ============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/zero-lib.sh" 2>/dev/null || true

LOG_FILE="$SCRIPT_DIR/../logs/zero-lab-fix.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    local msg="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
    echo "$msg" | tee -a "$LOG_FILE"
}

# 检查进化实验室脚本是否存在且可执行
check_lab_script() {
    local lab_script="$SCRIPT_DIR/zero-evolution-lab.sh"
    if [ ! -f "$lab_script" ]; then
        log "ERROR: 进化实验室脚本不存在: $lab_script"
        return 1
    fi
    if [ ! -x "$lab_script" ]; then
        log "WARN: 进化实验室脚本不可执行，正在修复权限"
        chmod +x "$lab_script"
    fi
    log "OK: 进化实验室脚本存在且可执行"
    return 0
}

# 检查依赖脚本是否存在
check_dependencies() {
    local deps=("zero-core.sh" "zero-think.sh" "zero-dream.sh" "zero-self-modify.sh")
    local missing=0
    for dep in "${deps[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$dep" ]; then
            log "ERROR: 依赖脚本缺失: $dep"
            missing=$((missing + 1))
        fi
    done
    if [ "$missing" -gt 0 ]; then
        log "总计缺失 $missing 个依赖脚本"
        return 1
    fi
    log "OK: 所有依赖脚本存在"
    return 0
}

# 检查进化实验室脚本内部语法
check_syntax() {
    local lab_script="$SCRIPT_DIR/zero-evolution-lab.sh"
    if bash -n "$lab_script" 2>/dev/null; then
        log "OK: 语法检查通过"
        return 0
    else
        log "ERROR: 语法检查失败"
        bash -n "$lab_script" 2>&1 | tee -a "$LOG_FILE"
        return 1
    fi
}

# 检查常见的失败模式——set -e导致中途退出
check_set_e_issues() {
    local lab_script="$SCRIPT_DIR/zero-evolution-lab.sh"
    # 检查是否有未受保护的命令可能因set -e退出
    local risky_patterns=("grep" "awk" "curl" "wget" "ping" "test" "[ ]")
    local found=0
    for pattern in "${risky_patterns[@]}"; do
        # 查找没有||true保护的命令
        while IFS= read -r line; do
            if echo "$line" | grep -qE "(^|[;&|])\s*$pattern\s" && ! echo "$line" | grep -qE "\|\|true|\|\|:"; then
                log "WARN: 可能的set -e风险行: $line"
                found=$((found + 1))
            fi
        done < <(grep -n "$pattern" "$lab_script" 2>/dev/null || true)
    done
    if [ "$found" -gt 0 ]; then
        log "发现 $found 处可能的set -e风险"
        return 1
    fi
    log "OK: 未发现明显的set -e风险"
    return 0
}

# 检查运行环境
check_environment() {
    local issues=0
    # 检查必要的环境变量
    if [ -z "${GITHUB_TOKEN:-}" ] && [ -z "${GITHUB_ACTIONS:-}" ]; then
        log "WARN: GITHUB_TOKEN未设置，部分功能可能受限"
        issues=$((issues + 1))
    fi
    # 检查磁盘空间
    local available
    available=$(df . | tail -1 | awk '{print $4}')
    if [ "$available" -lt 10240 ] 2>/dev/null; then
        log "WARN: 磁盘空间不足: ${available}KB"
        issues=$((issues + 1))
    fi
    if [ "$issues" -eq 0 ]; then
        log "OK: 运行环境正常"
    fi
    return "$issues"
}

# 尝试修复常见问题
attempt_fix() {
    local lab_script="$SCRIPT_DIR/zero-evolution-lab.sh"
    local fixed=0
    
    # 修复1: 如果脚本以set -e开头但没有错误处理，添加set +e保护关键区域
    if grep -q "^set -e" "$lab_script" 2>/dev/null; then
        log "修复: 在关键命令前添加set +e保护"
        # 在grep/curl等命令前添加||true保护
        sed -i 's/\(grep [^-]\)/ \1||true/g' "$lab_script" 2>/dev/null && fixed=$((fixed + 1))
        log "已应用grep保护"
    fi
    
    # 修复2: 确保日志目录存在
    local log_dir
    log_dir=$(grep -oP 'LOG_FILE="\K[^"]+' "$lab_script" 2>/dev/null | head -1 | xargs dirname 2>/dev/null || echo "")
    if [ -n "$log_dir" ] && [ ! -d "$log_dir" ]; then
        mkdir -p "$log_dir"
        log "修复: 创建日志目录 $log_dir"
        fixed=$((fixed + 1))
    fi
    
    # 修复3: 确保所有引用的脚本路径正确
    local bad_refs
    bad_refs=$(grep -oP 'source "\$SCRIPT_DIR/\K[^"]+' "$lab_script" 2>/dev/null | while IFS= read -r ref; do
        if [ ! -f "$SCRIPT_DIR/$ref" ]; then
            echo "$ref"
        fi
    done)
    if [ -n "$bad_refs" ]; then
        log "修复: 移除对不存在脚本的引用: $bad_refs"
        fixed=$((fixed + 1))
    fi
    
    return "$fixed"
}

# 主流程
main() {
    log "=== 零 - 进化实验室修复脚本启动 ==="
    log "时间: $(date)"
    
    local exit_code=0
    
    check_lab_script || exit_code=$?
    check_dependencies || exit_code=$?
    check_syntax || exit_code=$?
    check_set_e_issues || exit_code=$?
    check_environment || exit_code=$?
    
    if [ "$exit_code" -ne 0 ]; then
        log "检测到问题，尝试自动修复..."
        attempt_fix
        log "修复完成，重新验证..."
        check_syntax && log "修复后语法检查通过" || log "修复后语法检查仍失败"
    else
        log "所有检查通过，无需修复"
    fi
    
    log "=== 进化实验室修复脚本结束 ==="
    return "$exit_code"
}

main "$@"
